// LAB-05.1 behavioral SDHC SPI card: initialization + sector 0 with valid CRC16.
// This checks protocol sequencing, not an actual card or FPGA timing.
`timescale 1ns/1ps
module tb_sd02_multilba;
    reg clk=0;
    always #18.5 clk=~clk;
    reg reset_n=0, start=0;
    reg [31:0] read_lba=0;
    reg [31:0] active_lba=0;
    reg [31:0] observed_lba=0;
    reg [31:0] cmd_arg=0;
    integer read_no=0;
    integer init_no=0;
    wire sck,mosi,cs_n,busy,done,initialized;
    reg miso=1;
    wire [7:0] error_code,peek_data;
    reg [8:0] peek_addr=0;
    integer byte_bits=0, cmd_count=0, q_read=0, q_write=0, q_bit=7;
    reg [7:0] cmd_shift=0;
    reg [7:0] cmd_first=0;
    reg [7:0] q[0:8191];
    integer attempts=0, reads=0, command_total=0;
    integer i;
    reg [15:0] data_crc=0;
    reg [7:0] received_byte;

    lab05_sd_read_sector #(.HALF_PERIOD(3),.STARTUP_CYCLES(12)) dut (
        .clk(clk),.reset_n(reset_n),.start(start),.read_lba(read_lba),.sd_miso(miso),
        .sd_sck(sck),.sd_mosi(mosi),.sd_cs_n(cs_n),
        .busy(busy),.done(done),.initialized(initialized),
        .error_code(error_code),.peek_addr(peek_addr),.peek_data(peek_data)
    );

    function [7:0] sector_byte;
        input integer addr;
        begin
            if(addr==0) sector_byte=active_lba[7:0] ^ 8'heb;
            else if(addr==1) sector_byte=active_lba[15:8] ^ 8'h58;
            else if(addr==2) sector_byte=active_lba[23:16] ^ 8'h90;
            else if(addr==510) sector_byte=8'h55;
            else if(addr==511) sector_byte=8'haa;
            else sector_byte=(addr & 255) ^ 8'ha5 ^ active_lba[7:0];
        end
    endfunction

    function [15:0] crc16_byte;
        input [15:0] seed;
        input [7:0] value;
        reg [15:0] c;
        integer b;
        begin
            c=seed;
            for(b=7;b>=0;b=b-1)
                if(c[15]^value[b]) c={c[14:0],1'b0}^16'h1021;
                else c={c[14:0],1'b0};
            crc16_byte=c;
        end
    endfunction

    task queue_byte;
        input [7:0] value;
        begin
            if(q_write>8191) $fatal(1,"SD model response queue overflow");
            q[q_write]=value;
            q_write=q_write+1;
        end
    endtask

    task on_command;
        input [7:0] byte0;
        begin
            command_total=command_total+1;
            case (byte0)
                8'h40: begin init_no=init_no+1; queue_byte(8'h01); end
                8'h48: begin
                    queue_byte(8'h01);
                    queue_byte(8'h00);queue_byte(8'h00);
                    queue_byte(8'h01);queue_byte(8'haa);
                end
                8'h77: queue_byte(8'h01);
                8'h69: begin
                    attempts=attempts+1;
                    queue_byte(attempts==1 ? 8'h01 : 8'h00);
                end
                8'h7a: begin
                    queue_byte(8'h00);queue_byte(8'hc0);
                    queue_byte(8'h00);queue_byte(8'h00);queue_byte(8'h00);
                end
                8'h51: begin
                    reads=reads+1;
                    active_lba=cmd_arg;
                    observed_lba=cmd_arg;
                    queue_byte(8'h00);
                    queue_byte(8'hff);
                    queue_byte(8'hfe);
                    data_crc=0;
                    for(i=0;i<512;i=i+1) begin
                        queue_byte(sector_byte(i));
                        data_crc=crc16_byte(data_crc,sector_byte(i));
                    end
                    queue_byte(data_crc[15:8]);
                    queue_byte(reads==3 ? (data_crc[7:0] ^ 8'h01) : data_crc[7:0]);
                end
                default: $fatal(1,"unexpected SD command %02x",byte0);
            endcase
        end
    endtask

    // SPI mode 0: sample MOSI on rising SCK.
    always @(posedge sck) begin
        if (cs_n) begin
            byte_bits=0;cmd_count=0;cmd_shift=0;
        end else begin
            received_byte={cmd_shift[6:0],mosi};
            cmd_shift=received_byte;
            byte_bits=byte_bits+1;
            if(byte_bits==8) begin
                byte_bits=0;
                if(cmd_count==0) begin
                    if ((received_byte & 8'hc0)==8'h40) begin
                        cmd_first=received_byte;
                        cmd_arg=0;
                        cmd_count=1;
                    end
                end else begin
                    if(cmd_count>=1 && cmd_count<=4)
                        cmd_arg={cmd_arg[23:0],received_byte};
                    cmd_count=cmd_count+1;
                    if(cmd_count==6) begin
                        on_command(cmd_first);
                        cmd_count=0;
                    end
                end
            end
        end
    end
    // Drive the subsequent response bit on falling SCK.
    always @(negedge sck) begin
        if (cs_n) miso<=1'b1;
        else if(q_read<q_write) begin
            miso<=q[q_read][q_bit];
            if(q_bit==0) begin
                q_bit=7;q_read=q_read+1;
            end else q_bit=q_bit-1;
        end else miso<=1'b1;
    end

    task assert_sector;
        input [8:0] a;
        begin
            @(negedge clk); peek_addr=a;
            repeat(2) @(negedge clk);
            if(peek_data !== sector_byte(a))
                $fatal(1,"sector byte mismatch address %0d got %02x expected %02x",a,peek_data,sector_byte(a));
        end
    endtask

    integer ticks=0;
    task read_and_check;
        input [31:0] lba;
        input expect_crc_bad;
        begin
            @(negedge clk); read_lba=lba; start=1;
            @(negedge clk); start=0;
            ticks=0;
            while (!done && ticks<300000) begin
                @(negedge clk); ticks=ticks+1;
            end
            if(!done) $fatal(1,"timeout for LBA=%h",lba);
            if(observed_lba!==lba) $fatal(1,"CMD17 address mismatch got=%h expected=%h",observed_lba,lba);
            if(error_code!==(expect_crc_bad ? 8'hea : 8'h00))
                $fatal(1,"CRC result wrong lba=%h code=%h",lba,error_code);
            if(!initialized || cs_n!==1 || busy!==0)
                $fatal(1,"card not ready after read");
            if(!expect_crc_bad) begin
                assert_sector(0); assert_sector(1); assert_sector(123);
                assert_sector(256); assert_sector(510); assert_sector(511);
            end
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(5) @(negedge clk); reset_n=1;
        read_and_check(32'd0,0);
        read_and_check(32'd1,0);
        read_and_check(32'd2048,1);
        read_and_check(32'h00010005,0);
        if(reads!=4 || init_no!=1 || attempts!=2 || command_total!=11)
            $fatal(1,"reinit or command mismatch read=%0d init=%0d attempts=%0d cmd=%0d",
                   reads,init_no,attempts,command_total);
        $display("SD02_MULTI_LBA_TB_PASS: 0,1,2048 CRC error,65541 recovery; one init");
        $finish;
    end
    initial begin
        #500000000;$fatal(1,"SD model watchdog");
    end
endmodule
