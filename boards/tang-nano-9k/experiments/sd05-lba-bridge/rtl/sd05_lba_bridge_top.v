// SD-05, autonomous read-only CMD17 UART block bridge on Tang Nano 9K.
// Python controls LBA and FAT32; FPGA implements UART/SD SPI and sector RAM.
// Request  A5 52 seq lba[4 LE] CRC16[2 LE] (9 bytes).
// Success  5A 44 seq lba[4 LE] 00 00 sector[512] CRC16[2 LE] (523 bytes).
// Error    5A 45 seq lba[4 LE] error CRC16[2 LE] (10 bytes).
// CRC16 CCITT-FALSE poly1021 init FFFF. No SD write commands.
// 27MHz single fabric clock, conservative SD SPI, synchronous BSRAM.
// SPI SD MISO external return timing is NOT independently characterized.
// SPDX-License-Identifier: MIT
module sd05_lba_bridge_top #(
 parameter integer HALF_PERIOD=64,
 parameter integer STARTUP_CYCLES=27000,
 parameter integer UART_BAUD=115200
)(
 input wire clk,reset_n,uart_rx,sd_miso,
 output wire uart_tx,sd_sck,sd_mosi,sd_cs_n,
 output wire [5:0] led_n
);
 localparam [3:0] IDLE=0,RX_FRAME=1,READ_START=2,READ_WAIT=3,
   RESP_INIT=4,RESP_PREP=5,RESP_RAM1=6,RESP_RAM2=7,
   RESP_KICK=8,RESP_WAIT_START=9,RESP_WAIT_DONE=10;
 reg [3:0] state;
 wire [7:0] rx_data;
 wire rx_valid,rx_error;
 reg [3:0] rx_pos;
 reg [7:0] seq,crc_lo;
 reg [31:0] lba;
 reg [15:0] req_crc,reply_crc;
 reg good_reply;
 reg [7:0] error_status;
 reg [9:0] resp_pos;
 reg [8:0] peek_addr;
 wire [7:0] peek_data;
 reg sd_start;
 wire sd_busy,sd_done,initialized;
 wire [7:0] sd_error;
 wire uart_busy;
 reg uart_start;
 reg [7:0] uart_data;
 reg last_success,last_failure;

 sd05_uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD))
   u_rx(.clk(clk),.reset_n(reset_n),.rx(uart_rx),
   .data(rx_data),.valid(rx_valid),.framing_error(rx_error));
 uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD))
   u_uart(.clk(clk),.reset_n(reset_n),.start(uart_start),
   .data(uart_data),.tx(uart_tx),.busy(uart_busy));
 lab05_sd_read_sector #(.HALF_PERIOD(HALF_PERIOD),
   .STARTUP_CYCLES(STARTUP_CYCLES))
   u_reader(.clk(clk),.reset_n(reset_n),.start(sd_start),.read_lba(lba),
   .sd_miso(sd_miso),.sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),
   .busy(sd_busy),.done(sd_done),.initialized(initialized),
   .error_code(sd_error),.peek_addr(peek_addr),.peek_data(peek_data));

 function [15:0] crc_next;
   input [15:0] previous;
   input [7:0] value;
   reg [15:0] c;
   integer i;
   begin
     c=previous ^ {value,8'h00};
     for(i=0;i<8;i=i+1)
       c=c[15] ? {c[14:0],1'b0}^16'h1021 : {c[14:0],1'b0};
     crc_next=c;
   end
 endfunction
 function [7:0] frame_byte;
   input [9:0] index;
   input success;
   input [7:0] fseq,ferror;
   input [31:0] flba;
   input [15:0] fcrc;
   begin
     case(index)
       10'd0:frame_byte=8'h5A;
       10'd1:frame_byte=success?8'h44:8'h45;
       10'd2:frame_byte=fseq;
       10'd3:frame_byte=flba[7:0];
       10'd4:frame_byte=flba[15:8];
       10'd5:frame_byte=flba[23:16];
       10'd6:frame_byte=flba[31:24];
       10'd7:frame_byte=success?8'h00:ferror;
       10'd8:frame_byte=success?8'h00:fcrc[7:0];
       10'd9:frame_byte=fcrc[15:8]; // error frame only
       10'd521:frame_byte=fcrc[7:0];
       10'd522:frame_byte=fcrc[15:8];
       default:frame_byte=8'h00;
     endcase
   end
 endfunction
 assign led_n = last_success ? 6'b111110 :
                last_failure ? 6'b111101 : 6'b111111;
 wire _unused_status=sd_busy ^ initialized;

 always @(posedge clk or negedge reset_n) begin
 if(!reset_n)begin
   state<=IDLE;rx_pos<=0;seq<=0;lba<=0;crc_lo<=0;
   req_crc<=16'hFFFF;reply_crc<=16'hFFFF;good_reply<=0;
   error_status<=0;resp_pos<=0;peek_addr<=0;
   sd_start<=0;uart_start<=0;uart_data<=0;
   last_success<=0;last_failure<=0;
 end else begin
   sd_start<=0;uart_start<=0;
   case(state)
     IDLE:if(rx_valid && rx_data==8'hA5)begin
       req_crc<=crc_next(16'hFFFF,8'hA5);
       rx_pos<=1;state<=RX_FRAME;
     end
     RX_FRAME:if(rx_error)state<=IDLE;
     else if(rx_valid)begin
       case(rx_pos)
         1:if(rx_data!=8'h52)state<=IDLE;
           else begin req_crc<=crc_next(req_crc,rx_data);rx_pos<=2;end
         2:begin seq<=rx_data;req_crc<=crc_next(req_crc,rx_data);rx_pos<=3;end
         3:begin lba[7:0]<=rx_data;req_crc<=crc_next(req_crc,rx_data);rx_pos<=4;end
         4:begin lba[15:8]<=rx_data;req_crc<=crc_next(req_crc,rx_data);rx_pos<=5;end
         5:begin lba[23:16]<=rx_data;req_crc<=crc_next(req_crc,rx_data);rx_pos<=6;end
         6:begin lba[31:24]<=rx_data;req_crc<=crc_next(req_crc,rx_data);rx_pos<=7;end
         7:begin crc_lo<=rx_data;rx_pos<=8;end
         8:if({rx_data,crc_lo}==req_crc)state<=READ_START;
           else begin
             error_status<=8'hF1;good_reply<=0;
             last_success<=0;last_failure<=1;state<=RESP_INIT;
           end
         default:state<=IDLE;
       endcase
     end
     READ_START:begin sd_start<=1;state<=READ_WAIT;end
     READ_WAIT:if(sd_done)begin
       if(sd_error==0)begin
         good_reply<=1;last_success<=1;last_failure<=0;
       end else begin
         good_reply<=0;error_status<=sd_error;
         last_success<=0;last_failure<=1;
       end
       state<=RESP_INIT;
     end
     RESP_INIT:begin
       reply_crc<=16'hFFFF;resp_pos<=0;state<=RESP_PREP;
     end
     RESP_PREP:if(good_reply && resp_pos>=9 && resp_pos<=520)begin
       peek_addr<=resp_pos-10'd9;
       state<=RESP_RAM1;
     end else begin
       uart_data<=frame_byte(resp_pos,good_reply,seq,error_status,lba,reply_crc);
       if(resp_pos < (good_reply ? 10'd521:10'd8))
         reply_crc<=crc_next(reply_crc,
           frame_byte(resp_pos,good_reply,seq,error_status,lba,reply_crc));
       state<=RESP_KICK;
     end
     // Reader's BSRAM output registered on clk. Two cycles after address.
     RESP_RAM1:state<=RESP_RAM2;
     RESP_RAM2:begin
       uart_data<=peek_data;
       reply_crc<=crc_next(reply_crc,peek_data);
       state<=RESP_KICK;
     end
     RESP_KICK:if(!uart_busy)begin uart_start<=1;state<=RESP_WAIT_START;end
     RESP_WAIT_START:if(uart_busy)state<=RESP_WAIT_DONE;
     RESP_WAIT_DONE:if(!uart_busy)begin
       if(resp_pos==(good_reply?10'd522:10'd9))state<=IDLE;
       else begin resp_pos<=resp_pos+1'b1;state<=RESP_PREP;end
     end
     default:state<=IDLE;
   endcase
 end
 end
endmodule
