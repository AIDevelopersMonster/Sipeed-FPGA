// SD-04 read-only root sector dump over UART (HEX, 1024 characters).
// Uses frozen SD-03 scanner and SDHC core. No FAT32 directory logic in fabric.
// After validated MBR/VBR, issues CMD17 at the computed root LBA.
// One 27MHz clock domain; RAM is synchronous; no SD writes.
// SPDX-License-Identifier: MIT
module sd04_root_dump_top #(
 parameter integer HALF_PERIOD=64,
 parameter integer STARTUP_CYCLES=27000,
 parameter integer UART_BAUD=115200
)(
 input wire clk, reset_n, sd_miso,
 output wire sd_sck, sd_mosi, sd_cs_n, uart_tx,
 output wire [5:0] led_n
);
 reg scan_start, root_start;
 wire scan_sd_start, sd_busy, sd_done, initialized;
 wire [31:0] scan_sd_lba;
 wire [7:0] sd_error, peek_data;
 reg [8:0] root_addr;
 wire [8:0] scan_addr;
 wire scan_done;
 wire [3:0] scan_result;
 wire [31:0] vol_lba,fat_lba,data_lba,root_lba,cluster_count;
 reg [3:0] state;
 localparam BOOT=0,SCAN=1,READ_ROOT=2,WAIT_ROOT=3,
            PREP=4,SETTLE1=5,SETTLE2=6,
            SEND_HI=7,WAIT_HI=8,IDLE_HI=9,
            SEND_LO=10,WAIT_LO=11,IDLE_LO=12,
            TAIL=13,WAIT_TAIL=14,HALT=15;
 reg [9:0] pos; // 0..1027, includes CRLF framing
 reg [7:0] byte_hold;
 reg [7:0] tx_data;
 reg tx_start;
 wire tx_busy;
 reg [7:0] last_error;
 reg valid_root;
 wire [8:0] selected_addr=(state==BOOT || state==SCAN) ? scan_addr : root_addr;
 wire reader_start=(state==BOOT || state==SCAN) ? scan_sd_start : root_start;
 wire [31:0] reader_lba=(state==BOOT || state==SCAN) ? scan_sd_lba : root_lba;
 lab05_sd_read_sector #(.HALF_PERIOD(HALF_PERIOD),
  .STARTUP_CYCLES(STARTUP_CYCLES)) u_reader(
 .clk(clk),.reset_n(reset_n),.start(reader_start),.read_lba(reader_lba),
 .sd_miso(sd_miso),.sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),
 .busy(sd_busy),.done(sd_done),.initialized(initialized),
 .error_code(sd_error),.peek_addr(selected_addr),.peek_data(peek_data));
 sd03_volume_scanner u_scanner(
 .clk(clk),.reset_n(reset_n),.start(scan_start),
 .sd_start(scan_sd_start),.sd_lba(scan_sd_lba),
 .sd_busy(sd_busy),.sd_done(sd_done),.sd_error(sd_error),
 .peek_addr(scan_addr),.peek_data(peek_data),
 .done(scan_done),.result(scan_result),
 .volume_lba(vol_lba),.fat_lba(fat_lba),
 .data_lba(data_lba),.root_lba(root_lba),.cluster_count(cluster_count));
 uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_uart(
 .clk(clk),.reset_n(reset_n),.start(tx_start),
 .data(tx_data),.tx(uart_tx),.busy(tx_busy));
 function [7:0] hex;
 input [3:0] n;
 begin hex=n<10 ? (8'd48+{4'b0,n}) : (8'd55+{4'b0,n});end
 endfunction
 // Frame: exactly 1024 uppercase hex chars followed by CR LF on success;
 // on failure: "ERROR\r\n". Python must reject incomplete/invalid frames.
 // Boot status LEDs: L0 success, L1 failure (active low).
 assign led_n=valid_root ? 6'b111110 : 6'b111101;
 always @(posedge clk or negedge reset_n)begin
 if(!reset_n)begin
  state<=BOOT;scan_start<=0;root_start<=0;root_addr<=0;
  pos<=0;byte_hold<=0;tx_start<=0;tx_data<=0;
  last_error<=0;valid_root<=0;
 end else begin
  scan_start<=0;root_start<=0;tx_start<=0;
  case(state)
   BOOT:begin scan_start<=1;state<=SCAN;end
   SCAN:if(scan_done)begin
    if(scan_result==1 || scan_result==2)state<=READ_ROOT;
    else begin last_error<=8'he0;pos<=0;state<=TAIL;end
   end
   READ_ROOT:begin root_start<=1;state<=WAIT_ROOT;end
   WAIT_ROOT:if(sd_done)begin
    if(sd_error!=0)begin last_error<=sd_error;pos<=0;state<=TAIL;end
    else begin valid_root<=1;pos<=0;root_addr<=0;state<=SETTLE1;end
   end
   PREP:begin root_addr<=pos[9:1];state<=SETTLE1;end
   SETTLE1:state<=SETTLE2;
   SETTLE2:begin byte_hold<=peek_data;state<=SEND_HI;end
   SEND_HI:if(!tx_busy)begin tx_data<=hex(byte_hold[7:4]);tx_start<=1;state<=WAIT_HI;end
   WAIT_HI:if(tx_busy)state<=IDLE_HI;
   IDLE_HI:if(!tx_busy)state<=SEND_LO;
   SEND_LO:if(!tx_busy)begin tx_data<=hex(byte_hold[3:0]);tx_start<=1;state<=WAIT_LO;end
   WAIT_LO:if(tx_busy)state<=IDLE_LO;
   IDLE_LO:if(!tx_busy)begin
    if(pos==1023)begin pos<=0;state<=TAIL;end
    else begin pos<=pos+2;state<=PREP;end
   end
   TAIL:if(!tx_busy)begin
    if(valid_root)tx_data<= pos==0 ? 8'h0d : 8'h0a;
    else case(pos)
     0:tx_data<="E";1:tx_data<="R";2:tx_data<="R";
     3:tx_data<="O";4:tx_data<="R";5:tx_data<=8'h0d;
     default:tx_data<=8'h0a;
    endcase
    tx_start<=1;state<=WAIT_TAIL;
   end
   WAIT_TAIL:if(tx_busy)state<=15; // completed below using HALT? needs transition
   HALT:if(!tx_busy)begin
    if(valid_root ? pos==1 : pos==6)state<=HALT;
    else begin pos<=pos+1'b1;state<=TAIL;end
   end
   default:state<=HALT;
  endcase
 end
 end
 wire unused_signals=initialized ^ sd_busy ^ ^vol_lba ^ ^fat_lba ^
  ^data_lba ^ ^cluster_count ^ ^last_error;
endmodule
