// Standalone PC <-> UART <-> FPGA <-> SDHC sector bridge.
// Read:  SD-05-compatible A5 52 seq LBA32LE CRC16LE (9 bytes).
// Write: A5 57 seq LBA32LE old_sector[512] new_sector[512] CRC16LE
//        (1033 bytes). Write ACK: 5A 57 seq LBA32LE status CRC16LE.
// Read reply stays SD-05-compatible (ZD 523 / ZE 10 bytes).
// WRITE LOCK: write range is compiled into hardware; default (0,0) DENIES
// ALL writes. The caller must provide exact old-sector bytes and a valid CRC.
// FPGA reads and compares ALL 512 old bytes, writes with CMD24, reads again
// with CMD17 and verifies all 512 new bytes before acknowledging.
// Do not use any write-enabled bitstream on an irreplaceable SD card.
// Independent SD-06 experiment: no PiKoSoL CPU/HDMI modifications.
// SPDX-License-Identifier: MIT
module sd06_rw_bridge_top #(
    parameter integer HALF_PERIOD=64,
    parameter integer STARTUP_CYCLES=27000,
    parameter integer UART_BAUD=115200,
    parameter [31:0] WRITE_FIRST_LBA=32'd0,
    parameter [31:0] WRITE_LAST_LBA=32'd0
)(
    input wire clk,reset_n,uart_rx,sd_miso,
    output wire uart_tx,sd_sck,sd_mosi,sd_cs_n,
    output wire [5:0] led_n
);
    localparam [4:0] ST_IDLE=0,ST_RX=1,ST_READ_START=2,ST_READ_WAIT=3,
        ST_OLD_ADDR=4,ST_OLD_WAIT1=5,ST_OLD_WAIT2=6,
        ST_WRITE_START=7,ST_WRITE_WAIT=8,
        ST_VERIFY_START=9,ST_VERIFY_WAIT=10,
        ST_NEW_ADDR=11,ST_NEW_WAIT1=12,ST_NEW_WAIT2=13,
        ST_REPLY_INIT=14,ST_REPLY_PREP=15,ST_REPLY_RAM1=16,
        ST_REPLY_RAM2=17,ST_TX_KICK=18,ST_TX_WAIT1=19,ST_TX_WAIT2=20;
    reg [4:0] state;
    wire [7:0] rx_byte;
    wire rx_valid,rx_frame_error;
    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_byte;
    sd05_uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_rx(
        .clk(clk),.reset_n(reset_n),.rx(uart_rx),
        .data(rx_byte),.valid(rx_valid),.framing_error(rx_frame_error));
    uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_tx(
        .clk(clk),.reset_n(reset_n),.start(tx_start),.data(tx_byte),
        .tx(uart_tx),.busy(tx_busy));

    reg [10:0] rx_pos;
    reg [23:0] rx_idle_cycles;
    reg [7:0] seq;
    reg [31:0] lba;
    reg is_write;
    reg [15:0] req_crc;
    reg [7:0] req_crc_lo;
    reg old_we,new_we;
    reg [8:0] old_waddr,new_waddr;
    reg [7:0] old_wbyte,new_wbyte;
    reg [7:0] old_sector[0:511] /* synthesis syn_ramstyle = "block_ram" */;
    reg [7:0] new_sector[0:511] /* synthesis syn_ramstyle = "block_ram" */;
    reg [7:0] old_rdata,new_rdata;
    reg [8:0] cmp_pos;
    always @(posedge clk) begin
        if(old_we)old_sector[old_waddr]<=old_wbyte;
        if(new_we)new_sector[new_waddr]<=new_wbyte;
        old_rdata<=old_sector[cmp_pos];
        new_rdata<=new_sector[cmp_pos];
    end

    wire rd_sck,rd_mosi,rd_cs_n,rd_busy,rd_done,rd_initialized;
    wire [7:0] rd_error,rd_peek_data;
    reg rd_start;
    reg [8:0] rd_peek_addr;
    lab05_sd_read_sector #(.HALF_PERIOD(HALF_PERIOD),
        .STARTUP_CYCLES(STARTUP_CYCLES)) u_reader(
        .clk(clk),.reset_n(reset_n),.start(rd_start),.read_lba(lba),
        .sd_miso(sd_miso),.sd_sck(rd_sck),.sd_mosi(rd_mosi),
        .sd_cs_n(rd_cs_n),.busy(rd_busy),.done(rd_done),
        .initialized(rd_initialized),.error_code(rd_error),
        .peek_addr(rd_peek_addr),.peek_data(rd_peek_data));

    reg wr_start,wr_clear,wr_load_valid;
    reg [8:0] wr_load_addr;
    reg [7:0] wr_load_byte;
    reg mux_write;
    wire wr_sck,wr_mosi,wr_cs_n,wr_busy,wr_done,wr_payload_ready;
    wire [7:0] wr_error;
    // Only the writer has an independent reset during aborted packets.
    wire writer_reset_n=reset_n && !wr_clear;
    sd06_cmd24_engine #(.HALF_PERIOD(HALF_PERIOD)) u_writer(
        .clk(clk),.reset_n(writer_reset_n),
        .load_valid(wr_load_valid),.load_addr(wr_load_addr),
        .load_byte(wr_load_byte),.start(wr_start),
        .card_ready(rd_initialized),.authorized(write_allow),
        .request_lba(lba),.approved_lba(lba),.sd_miso(sd_miso),
        .sd_sck(wr_sck),.sd_mosi(wr_mosi),.sd_cs_n(wr_cs_n),
        .busy(wr_busy),.done(wr_done),.error_code(wr_error),
        .payload_ready(wr_payload_ready));

    assign sd_sck=mux_write ? wr_sck : rd_sck;
    assign sd_mosi=mux_write ? wr_mosi : rd_mosi;
    assign sd_cs_n=mux_write ? wr_cs_n : rd_cs_n;
    wire write_allow=(WRITE_FIRST_LBA!=0 && WRITE_LAST_LBA>=WRITE_FIRST_LBA
                     && lba>=WRITE_FIRST_LBA && lba<=WRITE_LAST_LBA);
    wire _unused=rd_busy ^ wr_busy;

    function [15:0] crc_next;
      input [15:0] prior;
      input [7:0] val;
      reg [15:0] v;
      integer i;
      begin
        v=prior ^ {val,8'h00};
        for(i=0;i<8;i=i+1)
            v=v[15] ? ({v[14:0],1'b0} ^ 16'h1021) : {v[14:0],1'b0};
        crc_next=v;
      end
    endfunction

    reg response_write,response_read_data;
    reg [7:0] response_status;
    reg [9:0] response_pos;
    reg [15:0] response_crc;
    reg result_read,result_write,result_error;
    assign led_n=result_error ? 6'b111101 :
                 result_write ? 6'b111011 :
                 result_read ? 6'b111110 : 6'b111111;

    function [7:0] response_byte;
      input [9:0] index;
      input w_reply,read_data;
      input [7:0] fseq,fstatus;
      input [31:0] flba;
      input [15:0] current_crc;
      begin
        case(index)
          0:response_byte=8'h5a;
          1:response_byte=w_reply ? 8'h57 : (read_data ? 8'h44 : 8'h45);
          2:response_byte=fseq;
          3:response_byte=flba[7:0];
          4:response_byte=flba[15:8];
          5:response_byte=flba[23:16];
          6:response_byte=flba[31:24];
          7:response_byte=read_data ? 8'h00 : fstatus;
          8:response_byte=read_data ? 8'h00 : current_crc[7:0];
          9:response_byte=current_crc[15:8];
          521:response_byte=current_crc[7:0];
          522:response_byte=current_crc[15:8];
          default:response_byte=8'h00;
        endcase
      end
    endfunction

    always @(posedge clk or negedge reset_n) begin
      if(!reset_n)begin
        state<=ST_IDLE;rx_pos<=0;rx_idle_cycles<=0;seq<=0;lba<=0;
        is_write<=0;req_crc<=16'hffff;req_crc_lo<=0;
        old_we<=0;new_we<=0;old_waddr<=0;new_waddr<=0;
        old_wbyte<=0;new_wbyte<=0;cmp_pos<=0;
        rd_start<=0;rd_peek_addr<=0;
        wr_start<=0;wr_clear<=0;wr_load_valid<=0;
        wr_load_addr<=0;wr_load_byte<=0;mux_write<=0;
        tx_start<=0;tx_byte<=0;
        response_write<=0;response_read_data<=0;response_status<=0;
        response_pos<=0;response_crc<=16'hffff;
        result_read<=0;result_write<=0;result_error<=0;
      end else begin
        rd_start<=0;wr_start<=0;wr_clear<=0;wr_load_valid<=0;
        old_we<=0;new_we<=0;tx_start<=0;
        case(state)
          ST_IDLE:if(rx_valid && rx_byte==8'ha5)begin
            req_crc<=crc_next(16'hffff,8'ha5);
            rx_pos<=1;rx_idle_cycles<=0;
            // Flush any aborted writer packet. Never flush while CMD24 busy.
            wr_clear<=1;
            state<=ST_RX;
          end
          ST_RX:begin
            if(rx_frame_error || rx_idle_cycles>=24'd3000000)begin
              // Partial/invalid request cannot reach CMD24.
              state<=ST_IDLE;
            end else if(rx_valid)begin
              rx_idle_cycles<=0;
              case(rx_pos)
                1:if(rx_byte!=8'h52 && rx_byte!=8'h57)
                    state<=ST_IDLE;
                  else begin
                    is_write<=rx_byte==8'h57;
                    req_crc<=crc_next(req_crc,rx_byte);
                    rx_pos<=2;
                  end
                2:begin
                  seq<=rx_byte;req_crc<=crc_next(req_crc,rx_byte);
                  rx_pos<=3;
                end
                3,4,5,6:begin
                  case(rx_pos)
                    3:lba[7:0]<=rx_byte;
                    4:lba[15:8]<=rx_byte;
                    5:lba[23:16]<=rx_byte;
                    6:lba[31:24]<=rx_byte;
                  endcase
                  req_crc<=crc_next(req_crc,rx_byte);
                  rx_pos<=rx_pos+1'b1;
                end
                default:begin
                  if(!is_write)begin
                    if(rx_pos==7)begin req_crc_lo<=rx_byte;rx_pos<=8;end
                    else if(rx_pos==8)begin
                      response_write<=0;response_read_data<=0;
                      response_status<=8'hf7;
                      if({rx_byte,req_crc_lo}==req_crc)
                          state<=ST_READ_START;
                      else begin
                          result_error<=1;result_read<=0;result_write<=0;
                          state<=ST_REPLY_INIT;
                      end
                    end else state<=ST_IDLE;
                  end else if(rx_pos>=7 && rx_pos<=518)begin
                    old_waddr<=rx_pos-11'd7;
                    old_wbyte<=rx_byte;old_we<=1;
                    req_crc<=crc_next(req_crc,rx_byte);
                    rx_pos<=rx_pos+1'b1;
                  end else if(rx_pos>=519 && rx_pos<=1030)begin
                    new_waddr<=rx_pos-11'd519;
                    new_wbyte<=rx_byte;new_we<=1;
                    wr_load_addr<=rx_pos-11'd519;
                    wr_load_byte<=rx_byte;wr_load_valid<=1;
                    req_crc<=crc_next(req_crc,rx_byte);
                    rx_pos<=rx_pos+1'b1;
                  end else if(rx_pos==1031)begin
                    req_crc_lo<=rx_byte;rx_pos<=1032;
                  end else if(rx_pos==1032)begin
                    response_write<=1;response_read_data<=0;
                    if({rx_byte,req_crc_lo}!=req_crc)begin
                      response_status<=8'hf7;result_error<=1;
                      result_read<=0;result_write<=0;
                      state<=ST_REPLY_INIT;
                    end else if(!write_allow)begin
                      response_status<=8'hf1;result_error<=1;
                      result_read<=0;result_write<=0;
                      state<=ST_REPLY_INIT;
                    end else if(!wr_payload_ready)begin
                      response_status<=8'hf1;result_error<=1;
                      result_read<=0;result_write<=0;
                      state<=ST_REPLY_INIT;
                    end else state<=ST_READ_START;
                  end else state<=ST_IDLE;
                end
              endcase
            end else rx_idle_cycles<=rx_idle_cycles+1'b1;
          end
          ST_READ_START:begin
            rd_start<=1;state<=ST_READ_WAIT;
          end
          ST_READ_WAIT:if(rd_done)begin
            if(rd_error!=0)begin
              response_write<=is_write;response_read_data<=0;
              response_status<=is_write ? 8'hf8 : rd_error;
              result_error<=1;result_read<=0;result_write<=0;
              state<=ST_REPLY_INIT;
            end else if(is_write)begin
              cmp_pos<=0;state<=ST_OLD_ADDR;
            end else begin
              response_write<=0;response_read_data<=1;
              response_status<=0;result_read<=1;result_write<=0;
              result_error<=0;state<=ST_REPLY_INIT;
            end
          end
          ST_OLD_ADDR:begin
            rd_peek_addr<=cmp_pos;state<=ST_OLD_WAIT1;
          end
          ST_OLD_WAIT1:state<=ST_OLD_WAIT2;
          ST_OLD_WAIT2:begin
            if(rd_peek_data!==old_rdata)begin
              response_write<=1;response_read_data<=0;
              response_status<=8'hf9;result_error<=1;
              result_read<=0;result_write<=0;state<=ST_REPLY_INIT;
            end else if(cmp_pos==9'd511)
              state<=ST_WRITE_START;
            else begin cmp_pos<=cmp_pos+1'b1;state<=ST_OLD_ADDR;end
          end
          ST_WRITE_START:begin
            // Reader must be idle with CS released before bus hand-over.
            mux_write<=1;wr_start<=1;state<=ST_WRITE_WAIT;
          end
          ST_WRITE_WAIT:if(wr_done)begin
            mux_write<=0;
            if(wr_error!=0)begin
              response_write<=1;response_read_data<=0;
              response_status<=wr_error;result_error<=1;
              result_read<=0;result_write<=0;state<=ST_REPLY_INIT;
            end else state<=ST_VERIFY_START;
          end
          ST_VERIFY_START:begin rd_start<=1;state<=ST_VERIFY_WAIT;end
          ST_VERIFY_WAIT:if(rd_done)begin
            if(rd_error!=0)begin
              response_write<=1;response_read_data<=0;
              response_status<=8'hfb;result_error<=1;
              result_read<=0;result_write<=0;state<=ST_REPLY_INIT;
            end else begin cmp_pos<=0;state<=ST_NEW_ADDR;end
          end
          ST_NEW_ADDR:begin rd_peek_addr<=cmp_pos;state<=ST_NEW_WAIT1;end
          ST_NEW_WAIT1:state<=ST_NEW_WAIT2;
          ST_NEW_WAIT2:begin
            if(rd_peek_data!==new_rdata)begin
              response_write<=1;response_read_data<=0;
              response_status<=8'hfa;result_error<=1;
              result_read<=0;result_write<=0;state<=ST_REPLY_INIT;
            end else if(cmp_pos==9'd511)begin
              response_write<=1;response_read_data<=0;
              response_status<=0;result_write<=1;result_read<=0;
              result_error<=0;state<=ST_REPLY_INIT;
            end else begin cmp_pos<=cmp_pos+1'b1;state<=ST_NEW_ADDR;end
          end
          ST_REPLY_INIT:begin
            response_pos<=0;response_crc<=16'hffff;
            state<=ST_REPLY_PREP;
          end
          ST_REPLY_PREP:begin
            if(response_read_data && response_pos>=10'd9
                && response_pos<=10'd520)begin
              rd_peek_addr<=response_pos-10'd9;
              state<=ST_REPLY_RAM1;
            end else begin
              tx_byte<=response_byte(response_pos,response_write,
                response_read_data,seq,response_status,lba,response_crc);
              if(response_pos<(response_read_data ? 10'd521 : 10'd8))
                response_crc<=crc_next(response_crc,
                  response_byte(response_pos,response_write,
                    response_read_data,seq,response_status,lba,response_crc));
              state<=ST_TX_KICK;
            end
          end
          ST_REPLY_RAM1:state<=ST_REPLY_RAM2;
          ST_REPLY_RAM2:begin
            tx_byte<=rd_peek_data;
            response_crc<=crc_next(response_crc,rd_peek_data);
            state<=ST_TX_KICK;
          end
          ST_TX_KICK:if(!tx_busy)begin
            tx_start<=1;state<=ST_TX_WAIT1;
          end
          ST_TX_WAIT1:if(tx_busy)state<=ST_TX_WAIT2;
          ST_TX_WAIT2:if(!tx_busy)begin
            if(response_pos==(response_read_data?10'd522:10'd9))
              state<=ST_IDLE;
            else begin
              response_pos<=response_pos+1'b1;state<=ST_REPLY_PREP;
            end
          end
          default:state<=ST_IDLE;
        endcase
      end
    end
endmodule
