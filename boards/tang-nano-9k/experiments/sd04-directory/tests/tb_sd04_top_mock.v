// SD-04 full top behavioral handshake: mocked previously validated scanner and
// read-only SDHC sector buffer. Tests UART byte stream, LBA selection and status.
`timescale 1ns/1ps
module tb_sd04_top_mock;
reg clk=0,reset_n=0,miso=1;
always #5 clk=~clk;
wire sck,mosi,cs_n,uart_tx;
wire [5:0] led_n;
integer cycles=0;
sd04_directory_probe_top #(.HALF_PERIOD(3),.STARTUP_CYCLES(10),.UART_BAUD(13500000)) dut(
 .clk(clk),.reset_n(reset_n),.sd_miso(miso),.sd_sck(sck),
 .sd_mosi(mosi),.sd_cs_n(cs_n),.uart_tx(uart_tx),.led_n(led_n));
initial begin
 repeat(5)@(negedge clk);reset_n=1;
 while(cycles<100000 && led_n==6'b111111)begin
   @(negedge clk);cycles=cycles+1;
 end
 if(cycles>=100000)$fatal(1,"TOP did not complete");
 if(led_n!==6'b111110)$fatal(1,"Expected pass LED got=%b",led_n);
 if(dut.nfiles!==1 || dut.ndirs!==1 || dut.nlfn!==1 ||
    dut.nskip!==1 || dut.stop_reason!==1)
  $fatal(1,"directory counts F=%0d D=%0d L=%0d SKIP=%0d STOP=%0d",
         dut.nfiles,dut.ndirs,dut.nlfn,dut.nskip,dut.stop_reason);
 if(dut.u_reader.requests!==1 || dut.u_reader.last_lba!==32'd17472)
  $fatal(1,"wrong root CMD17 LBA=%0d reads=%0d",
         dut.u_reader.last_lba,dut.u_reader.requests);
 if(dut.u_report.u_tx.frames<150)
  $fatal(1,"UART too short frames=%0d",dut.u_report.u_tx.frames);
 $display("SD04_TOP_MOCK_PASS: discovery -> CMD17 LBA17472 -> directory -> UART, no writes");
 $finish;
end
initial begin #2000000;$fatal(1,"watchdog");end
endmodule
module sd03_volume_scanner(
 input wire clk,input wire reset_n,input wire start,
 output reg sd_start,output reg [31:0] sd_lba,
 input wire sd_busy,sd_done,input wire [7:0] sd_error,
 output reg [8:0] peek_addr,input wire [7:0] peek_data,
 output reg done,output reg [3:0] result,
 output reg [31:0] volume_lba,fat_lba,data_lba,root_lba,cluster_count
);
reg pending;
always @(posedge clk or negedge reset_n)begin
 if(!reset_n)begin
  done<=0;result<=0;volume_lba<=0;fat_lba<=0;data_lba<=0;
  root_lba<=0;cluster_count<=0;sd_start<=0;sd_lba<=0;peek_addr<=0;pending<=0;
 end else begin
  done<=0;
  if(start)pending<=1;
  else if(pending)begin
   done<=1;pending<=0;result<=1;
   volume_lba<=64;fat_lba<=2112;data_lba<=17472;root_lba<=17472;
   cluster_count<=983007;
  end
 end
end
endmodule
module lab05_sd_read_sector #(
 parameter integer HALF_PERIOD=64,STARTUP_CYCLES=27000
)(
 input wire clk,reset_n,start,input wire [31:0] read_lba,
 input wire sd_miso,output wire sd_sck,sd_mosi,output wire sd_cs_n,
 output reg busy,done,initialized,output reg [7:0] error_code,
 input wire [8:0] peek_addr,output reg [7:0] peek_data
);
assign sd_sck=0;assign sd_mosi=1;assign sd_cs_n=1;
integer count=0,requests=0;reg [31:0] last_lba=0;
function [7:0] b;
input [8:0] a;
begin
 b=0;
 case(a)
 0:b="R";1:b="E";2:b="A";3:b="D";4:b="M";5:b="E";6:b=" ";7:b=" ";
 8:b="T";9:b="X";10:b="T";11:b=8'h20;26:b=8'd5;28:b=8'hd2;29:b=8'h04;
 32:b="D";43:b=8'h10;
 64:b="L";75:b=8'h0f;
 96:b=8'he5;
 default:b=0;
 endcase
end
endfunction
always @(posedge clk)peek_data<=b(peek_addr);
always @(posedge clk or negedge reset_n)begin
 if(!reset_n)begin busy<=0;done<=0;initialized<=0;error_code<=0;count<=0;requests<=0;last_lba<=0;end
 else begin
 done<=0;
 if(start)begin
  if(read_lba!==17472)$fatal(1,"bad CMD17 LBA %0d",read_lba);
  requests<=requests+1;last_lba<=read_lba;
  busy<=1;count<=3;initialized<=1;error_code<=0;
 end else if(busy)begin
  if(count==0)begin busy<=0;done<=1;end
  else count<=count-1;
 end
 end
end
endmodule
module uart_tx_8n1 #(
 parameter integer CLOCK_HZ=27000000,BAUD=115200
)(input wire clk,input wire reset_n,input wire start,input wire [7:0] data,
  output wire tx,output reg busy);
assign tx=1;
integer frames=0;
reg pending;
always @(posedge clk or negedge reset_n)begin
 if(!reset_n)begin busy<=0;pending<=0;frames<=0;end
 else begin
 if(start&&!busy)begin busy<=1;pending<=1;frames<=frames+1;end
 else if(pending)begin pending<=0;end
 else if(busy)busy<=0;
 end
end
endmodule
