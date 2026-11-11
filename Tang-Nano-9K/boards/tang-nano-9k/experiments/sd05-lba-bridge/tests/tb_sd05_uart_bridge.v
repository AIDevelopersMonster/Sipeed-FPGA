// SD-05 end-to-end UART PHY -> request parser -> mock SD CMD17 ->
// synchronous sector RAM -> UART PHY -> response/CRC validator.
// Real UART RX/TX RTL, real bridge top, mock SD only. 27MHz clock.
// UART BAUD overridden to 2700000 for short simulation (10 clk/bit).
// This is a SIMULATION test, NOT physical SD-card acceptance.
`timescale 1ns/1ps

module lab05_sd_read_sector #(
 parameter integer HALF_PERIOD=64, STARTUP_CYCLES=27000
)(
 input wire clk,reset_n,start,input wire [31:0] read_lba,
 input wire sd_miso,output wire sd_sck,sd_mosi,
 output wire sd_cs_n,output reg busy,done,initialized,
 output reg [7:0] error_code,
 input wire [8:0] peek_addr,output reg [7:0] peek_data
);
 reg [31:0] seen_lba;
 reg [3:0] countdown;
 integer read_count;
 reg [7:0] sector[0:511];
 integer k;
 initial for(k=0;k<512;k=k+1)sector[k]=k[7:0] ^ 8'hA5;
 assign sd_sck=1'b0;
 assign sd_mosi=1'b1;
 assign sd_cs_n=1'b1;
 // Model the REAL SD-03 BSRAM interface: one-cycle registered read.
 always @(posedge clk) peek_data<=sector[peek_addr];
 always @(posedge clk or negedge reset_n)begin
 if(!reset_n)begin busy<=0;done<=0;initialized<=0;
   error_code<=0;countdown<=0;seen_lba<=0;read_count<=0;end
 else begin
   done<=0;
   if(start && !busy)begin
     busy<=1;countdown<=4;seen_lba<=read_lba;
     read_count<=read_count+1;
   end else if(busy)begin
     if(countdown!=0)countdown<=countdown-1'b1;
     else begin
       busy<=0;done<=1;initialized<=1;
       error_code<=(seen_lba==32'd64) ? 8'hE6 : 8'h00;
     end
   end
 end
 end
endmodule

module tb_sd05_uart_bridge;
 localparam integer BIT_CYCLES=10;
 reg clk=0,reset_n=0,uart_rx=1,sd_miso=1;
 wire uart_tx,sd_sck,sd_mosi,sd_cs_n;
 wire [5:0] led_n;
 wire [7:0] monitor_byte;
 wire monitor_valid,monitor_error;
 reg [7:0] observed[0:2047];
 integer observed_count=0;
 integer n,cycles;
 reg [15:0] crc;
 reg [7:0] b[0:8];
 reg [7:0] expected;
 sd05_lba_bridge_top #(.UART_BAUD(2700000),.HALF_PERIOD(2),
   .STARTUP_CYCLES(10)) dut(
   .clk(clk),.reset_n(reset_n),.uart_rx(uart_rx),.sd_miso(sd_miso),
   .uart_tx(uart_tx),.sd_sck(sd_sck),.sd_mosi(sd_mosi),
   .sd_cs_n(sd_cs_n),.led_n(led_n));
 sd05_uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(2700000))
   monitor(.clk(clk),.reset_n(reset_n),.rx(uart_tx),
   .data(monitor_byte),.valid(monitor_valid),
   .framing_error(monitor_error));
 always #5 clk=~clk;
 always @(posedge clk)begin
   if(monitor_error)$fatal(1,"UART monitor framing error");
   if(monitor_valid)begin
     if(observed_count>=2048)$fatal(1,"UART monitor overflow");
     observed[observed_count]<=monitor_byte;
     observed_count<=observed_count+1;
   end
 end
 function [15:0] next_crc;
 input [15:0] old;
 input [7:0] d;
 reg [15:0] c;
 integer x;
 begin
 c=old^{d,8'h00};
 for(x=0;x<8;x=x+1)
   c=c[15]?{c[14:0],1'b0}^16'h1021:{c[14:0],1'b0};
 next_crc=c;
 end
 endfunction
 task send_byte;
 input [7:0] x;
 integer j;
 begin
   uart_rx=0;
   repeat(BIT_CYCLES)@(negedge clk);
   for(j=0;j<8;j=j+1)begin
     uart_rx=x[j];repeat(BIT_CYCLES)@(negedge clk);
   end
   uart_rx=1;
   repeat(BIT_CYCLES)@(negedge clk);
 end
 endtask
 task send_request;
 input [31:0] lba;
 input [7:0] seq;
 input corrupt;
 integer j;
 reg [15:0] c;
 begin
   b[0]=8'hA5;b[1]=8'h52;b[2]=seq;
   b[3]=lba[7:0];b[4]=lba[15:8];
   b[5]=lba[23:16];b[6]=lba[31:24];
   c=16'hFFFF;
   for(j=0;j<7;j=j+1)c=next_crc(c,b[j]);
   b[7]=c[7:0] ^ (corrupt?8'h01:8'h00);
   b[8]=c[15:8];
   for(j=0;j<9;j=j+1)send_byte(b[j]);
 end
 endtask
 task wait_for_count;
 input integer target;
 input integer budget;
 begin
 cycles=0;
 while(observed_count<target && cycles<budget)begin
   @(negedge clk);cycles=cycles+1;
 end
 if(observed_count!=target)$fatal(1,
   "response count target=%0d got=%0d (budget=%0d)",target,observed_count,budget);
 end
 endtask
 task check_success;
 input integer base;
 input [31:0] lba;
 input [7:0] seq;
 integer i;
 reg [15:0] c;
 begin
   if(observed[base]!==8'h5A || observed[base+1]!==8'h44 ||
      observed[base+2]!==seq)$fatal(1,"success header mismatch");
   for(i=0;i<4;i=i+1)begin
     expected=(lba>>(8*i)) & 8'hFF;
     if(observed[base+3+i]!==expected)
       $fatal(1,"LBA echo mismatch at index %0d",i);
   end
   if(observed[base+7]!==0 || observed[base+8]!==0)
     $fatal(1,"success status must be 0000");
   for(i=0;i<512;i=i+1)begin
     expected=i[7:0]^8'hA5;
     if(observed[base+9+i]!==expected)
       $fatal(1,"sector byte %0d expected %h got %h",
         i,expected,observed[base+9+i]);
   end
   c=16'hFFFF;
   for(i=0;i<521;i=i+1)c=next_crc(c,observed[base+i]);
   if(observed[base+521]!==c[7:0] ||
      observed[base+522]!==c[15:8])
     $fatal(1,"success CRC mismatch: expected %h",c);
 end
 endtask
 task check_error;
 input integer base;
 input [31:0] lba;
 input [7:0] seq,code;
 integer i;
 reg [15:0] c;
 begin
   if(observed[base]!==8'h5A || observed[base+1]!==8'h45 ||
      observed[base+2]!==seq)$fatal(1,"error header mismatch");
   for(i=0;i<4;i=i+1)begin
     expected=(lba>>(8*i)) & 8'hFF;
     if(observed[base+3+i]!==expected)
       $fatal(1,"error LBA echo mismatch");
   end
   if(observed[base+7]!==code)
     $fatal(1,"error code expected %h got %h",code,observed[base+7]);
   c=16'hFFFF;
   for(i=0;i<8;i=i+1)c=next_crc(c,observed[base+i]);
   if(observed[base+8]!==c[7:0] ||
      observed[base+9]!==c[15:8])
     $fatal(1,"error CRC mismatch");
 end
 endtask

 initial begin
   repeat(10)@(negedge clk);reset_n=1;
   repeat(25)@(negedge clk);

   // Good request: ROOT sector, 523-byte framed reply, all payload bytes.
   send_request(32'd17472,8'd7,1'b0);
   wait_for_count(523,150000);
   check_success(0,32'd17472,8'd7);
   if(dut.u_reader.read_count!==1)$fatal(1,"wrong CMD17 request count");
   $display("SD05_UART_ROOT_FRAME_PASS: 523 bytes CRC and LBA echo");

   // Invalid request CRC -> error F1, never issue CMD17.
   send_request(32'd64,8'd8,1'b1);
   wait_for_count(533,15000);
   check_error(523,32'd64,8'd8,8'hF1);
   if(dut.u_reader.read_count!==1)$fatal(1,"CRC-invalid command issued CMD17");
   $display("SD05_UART_BAD_REQUEST_PASS: CRC rejection without SD command");

   // Proper request with mock SD CMD17 failure -> 10-byte error, no payload.
   send_request(32'd64,8'd9,1'b0);
   wait_for_count(543,15000);
   check_error(533,32'd64,8'd9,8'hE6);
   if(dut.u_reader.read_count!==2)$fatal(1,"expected second CMD17 attempt");
   $display("SD05_UART_SD_ERROR_PASS: CMD17 error propagated");

   // Another successful request proves recovery after a failed CMD17.
   send_request(32'd0,8'd10,1'b0);
   wait_for_count(1066,150000);
   check_success(543,32'd0,8'd10);
   if(dut.u_reader.read_count!==3)$fatal(1,"wrong third CMD17");
   repeat(150)@(negedge clk);
   if(observed_count!==1066)$fatal(1,"unexpected extra response bytes");
   $display("SD05_UART_BRIDGE_TB_PASS: two 512-byte reads, CRC, LBA echo, errors, no extra bytes");
   $finish;
 end
 initial begin
   #20000000;
   $fatal(1,"global timeout");
 end
endmodule
