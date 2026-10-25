// SD-07: isolated PiKoSoL PicoRV32 MMIO sector peripheral, 27 MHz sys clock.
// Reuses the SD-05 CMD17 and tested SD-06 CMD24 SPI engines.
// This is a NEW integration candidate, not a hardware-accepted bitstream.
// Does not parse/write FAT32 metadata; only accesses raw 512-byte sectors.
// The build-only FIT variant uses WRITE_LBA = 0xFFFFFFFE to retain
// the full CMD24 datapath. Its .fs is intentionally DELETED, never programmed.
// SPDX-License-Identifier: MIT
module sd07_sd_mmio #(
    parameter integer HALF_PERIOD = 64,
    parameter integer STARTUP_CYCLES = 27000,
    parameter [31:0] WRITE_FIRST_LBA = 32'd0,
    parameter [31:0] WRITE_LAST_LBA = 32'd0
)(
    input wire clk,
    input wire reset_n,
    input wire req_valid,
    input wire [7:0] req_addr,
    input wire [31:0] req_wdata,
    input wire [3:0] req_wstrb,
    output reg [31:0] req_rdata,
    input wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output wire sd_cs_n
);
    // 0x20000200 LBA         32-bit read/write
    // 0x20000204 CONTROL     WO: 1=CMD17; 2=CMD24; 4=clear buffers/status
    // 0x20000208 STATUS      bit0 busy, 1 done, 2 error, 3 initialized,
    //                      4 old512 ready, 5 new512 ready, 6 write_allowed,
    //                      7 valid_read, 8 verified_write
    // 0x2000020C ERROR       00=OK; F1=not allowed/not loaded; F8=pre-read;
    //                      F9=preimage mismatch; FA=new data mismatch;
    //                      FB=verify-read; F2..F6=CMD24 engine
    // 0x20000210 READ_INDEX  RW 0..511, synchronous read pipeline
    // 0x20000214 READ_BYTE   RO, 8-bit data from most recent CMD17
    // 0x20000218 NEW_BYTE    WO; append one byte to CMD24 payload (512 times)
    // 0x2000021C OLD_BYTE    WO; append one expected preimage byte (512 times)
    // 0x20000220 IDENT       RO 0x53443037 ("SD07")
    //
    // All access is word-aligned 32-bit MMIO. No DMA or CPU RAM sharing.
    // CONTROL start is ignored while busy; stale/partial frames cannot write.
    localparam [3:0] ST_IDLE=0,
        ST_READ_START=1,ST_READ_WAIT=2,
        ST_PRE_START=3,ST_PRE_WAIT=4,
        ST_OLD_ADDR=5,ST_OLD_WAIT1=6,ST_OLD_WAIT2=7,
        ST_WRITE_START=8,ST_WRITE_WAIT=9,
        ST_VERIFY_START=10,ST_VERIFY_WAIT=11,
        ST_NEW_ADDR=12,ST_NEW_WAIT1=13,ST_NEW_WAIT2=14;
    reg [3:0] state;
    reg [31:0] lba;
    reg [8:0] read_index;
    reg [9:0] old_count, new_count;
    reg [8:0] cmp_pos;
    reg [7:0] error_code;
    reg done_latched,valid_read,verified_write;
    wire write_allowed=(WRITE_FIRST_LBA!=0 &&
        WRITE_LAST_LBA>=WRITE_FIRST_LBA &&
        lba>=WRITE_FIRST_LBA && lba<=WRITE_LAST_LBA);
    wire mmio_write=req_valid && (req_wstrb==4'hf) &&
                    (req_addr[1:0]==2'b00);
    wire busy=(state!=ST_IDLE);

    reg [7:0] old_image [0:511] /* synthesis syn_ramstyle = "block_ram" */;
    reg [7:0] new_image [0:511] /* synthesis syn_ramstyle = "block_ram" */;
    reg [7:0] old_compare_data,new_compare_data;
    always @(posedge clk) begin
        old_compare_data<=old_image[cmp_pos];
        new_compare_data<=new_image[cmp_pos];
        if(mmio_write && !busy && req_addr==8'h1c &&
           old_count<10'd512)
            old_image[old_count[8:0]]<=req_wdata[7:0];
        if(mmio_write && !busy && req_addr==8'h18 &&
           new_count<10'd512)
            new_image[new_count[8:0]]<=req_wdata[7:0];
    end

    wire rd_sck,rd_mosi,rd_cs_n,rd_busy,rd_done,rd_initialized;
    wire [7:0] rd_error,rd_peek_data;
    reg rd_start;
    // Reader's synchronous RAM port serves both verification and CPU reads.
    wire [8:0] rd_peek_addr=busy ? cmp_pos : read_index;
    lab05_sd_read_sector #(
        .HALF_PERIOD(HALF_PERIOD), .STARTUP_CYCLES(STARTUP_CYCLES)
    ) u_reader(
        .clk(clk),.reset_n(reset_n),.start(rd_start),.read_lba(lba),
        .sd_miso(sd_miso),.sd_sck(rd_sck),.sd_mosi(rd_mosi),
        .sd_cs_n(rd_cs_n),.busy(rd_busy),.done(rd_done),
        .initialized(rd_initialized),.error_code(rd_error),
        .peek_addr(rd_peek_addr),.peek_data(rd_peek_data)
    );

    reg wr_start,wr_clear,wr_load_valid;
    reg [8:0] wr_load_addr;
    reg [7:0] wr_load_byte;
    reg mux_write;
    wire wr_sck,wr_mosi,wr_cs_n,wr_busy,wr_done,wr_payload_ready;
    wire [7:0] wr_error;
    sd06_cmd24_engine #(.HALF_PERIOD(HALF_PERIOD)) u_writer(
        .clk(clk),.reset_n(reset_n && !wr_clear),
        .load_valid(wr_load_valid),.load_addr(wr_load_addr),
        .load_byte(wr_load_byte),.start(wr_start),
        .card_ready(rd_initialized),.authorized(write_allowed),
        .request_lba(lba),.approved_lba(lba),.sd_miso(sd_miso),
        .sd_sck(wr_sck),.sd_mosi(wr_mosi),.sd_cs_n(wr_cs_n),
        .busy(wr_busy),.done(wr_done),.error_code(wr_error),
        .payload_ready(wr_payload_ready)
    );

    assign sd_sck=mux_write ? wr_sck : rd_sck;
    assign sd_mosi=mux_write ? wr_mosi : rd_mosi;
    assign sd_cs_n=mux_write ? wr_cs_n : rd_cs_n;
    wire _unused_busy=rd_busy ^ wr_busy;

    always @* begin
        case(req_addr)
            8'h00:req_rdata=lba;
            8'h04:req_rdata=32'd0;
            8'h08:req_rdata={23'd0,verified_write,valid_read,
                 write_allowed,wr_payload_ready,(old_count==10'd512),
                 rd_initialized,(error_code!=0),done_latched,busy};
            8'h0c:req_rdata={24'd0,error_code};
            8'h10:req_rdata={23'd0,read_index};
            8'h14:req_rdata={24'd0,rd_peek_data};
            8'h18:req_rdata={22'd0,new_count};
            8'h1c:req_rdata={22'd0,old_count};
            8'h20:req_rdata=32'h53443037;
            default:req_rdata=32'hBAD0_0007;
        endcase
    end

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            state<=ST_IDLE;lba<=0;read_index<=0;
            old_count<=0;new_count<=0;cmp_pos<=0;
            rd_start<=0;wr_start<=0;wr_clear<=0;
            wr_load_valid<=0;wr_load_addr<=0;wr_load_byte<=0;
            mux_write<=0;error_code<=0;done_latched<=0;
            valid_read<=0;verified_write<=0;
        end else begin
            rd_start<=0;wr_start<=0;wr_clear<=0;wr_load_valid<=0;
            if(state==ST_IDLE && mmio_write) begin
                case(req_addr)
                    8'h00:lba<=req_wdata;
                    8'h04:begin
                        if(req_wdata[2]) begin
                            wr_clear<=1;old_count<=0;new_count<=0;
                            error_code<=0;done_latched<=0;
                            valid_read<=0;verified_write<=0;
                        end else if(req_wdata[1]) begin
                            error_code<=0;done_latched<=0;
                            verified_write<=0;valid_read<=0;
                            if(!write_allowed || old_count!=10'd512 ||
                               new_count!=10'd512 || !wr_payload_ready) begin
                                error_code<=8'hf1;done_latched<=1;
                            end else state<=ST_PRE_START;
                        end else if(req_wdata[0]) begin
                            error_code<=0;done_latched<=0;
                            valid_read<=0;verified_write<=0;
                            state<=ST_READ_START;
                        end
                    end
                    8'h10:read_index<=req_wdata[8:0];
                    8'h18:if(new_count<10'd512) begin
                        wr_load_valid<=1;
                        wr_load_addr<=new_count[8:0];
                        wr_load_byte<=req_wdata[7:0];
                        new_count<=new_count+1'b1;
                    end
                    8'h1c:if(old_count<10'd512)
                        old_count<=old_count+1'b1;
                    default:;
                endcase
            end
            case(state)
                ST_IDLE:;
                ST_READ_START:begin
                    rd_start<=1;state<=ST_READ_WAIT;
                end
                ST_READ_WAIT:if(rd_done) begin
                    error_code<=rd_error;done_latched<=1;
                    valid_read<=rd_error==0;state<=ST_IDLE;
                end
                ST_PRE_START:begin
                    rd_start<=1;state<=ST_PRE_WAIT;
                end
                ST_PRE_WAIT:if(rd_done) begin
                    if(rd_error!=0) begin
                        error_code<=8'hf8;done_latched<=1;state<=ST_IDLE;
                    end else begin
                        cmp_pos<=0;state<=ST_OLD_ADDR;
                    end
                end
                ST_OLD_ADDR:state<=ST_OLD_WAIT1;
                ST_OLD_WAIT1:state<=ST_OLD_WAIT2;
                ST_OLD_WAIT2:begin
                    if(rd_peek_data!==old_compare_data) begin
                        error_code<=8'hf9;done_latched<=1;state<=ST_IDLE;
                    end else if(cmp_pos==9'd511) begin
                        state<=ST_WRITE_START;
                    end else begin
                        cmp_pos<=cmp_pos+1'b1;state<=ST_OLD_ADDR;
                    end
                end
                ST_WRITE_START:begin
                    mux_write<=1;wr_start<=1;state<=ST_WRITE_WAIT;
                end
                ST_WRITE_WAIT:if(wr_done) begin
                    mux_write<=0;
                    if(wr_error!=0) begin
                        error_code<=wr_error;done_latched<=1;state<=ST_IDLE;
                    end else state<=ST_VERIFY_START;
                end
                ST_VERIFY_START:begin
                    rd_start<=1;state<=ST_VERIFY_WAIT;
                end
                ST_VERIFY_WAIT:if(rd_done) begin
                    if(rd_error!=0) begin
                        error_code<=8'hfb;done_latched<=1;state<=ST_IDLE;
                    end else begin
                        cmp_pos<=0;state<=ST_NEW_ADDR;
                    end
                end
                ST_NEW_ADDR:state<=ST_NEW_WAIT1;
                ST_NEW_WAIT1:state<=ST_NEW_WAIT2;
                ST_NEW_WAIT2:begin
                    if(rd_peek_data!==new_compare_data) begin
                        error_code<=8'hfa;done_latched<=1;state<=ST_IDLE;
                    end else if(cmp_pos==9'd511) begin
                        error_code<=0;done_latched<=1;
                        verified_write<=1;valid_read<=1;state<=ST_IDLE;
                    end else begin
                        cmp_pos<=cmp_pos+1'b1;state<=ST_NEW_ADDR;
                    end
                end
                default:begin state<=ST_IDLE;mux_write<=0;end
            endcase
        end
    end
endmodule
