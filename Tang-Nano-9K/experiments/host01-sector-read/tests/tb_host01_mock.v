`timescale 1ns/1ps
// Mock 512-byte SD block behind HOST-01 transport engine, not physical SPI.
// Covers LBA, CRC and full 512-byte streaming with synchronous peek_data.
module tb_host01_mock;
 reg clk=0,reset_n=0;
 reg rx_valid=0;
 reg [7:0] rx_data=0;
 wire rx_ready,tx_valid,sd_start;
 reg tx_ready=0;
 wire [7:0] tx_data;
 wire [31:0] sd_lba;
 reg sd_busy=0,sd_done=0;
 reg [7:0] sd_error=0;
 wire [8:0] peek_addr;
 reg [7:0] peek_data=0;
 reg [7:0] sector[0:511];
 reg [7:0] received[0:520];
 integer n=0,i;
 reg [15:0] req_crc;
 reg [15:0] check_crc;
 reg [31:0] captured_lba=0;
 always #5 clk=~clk;
 always @(posedge clk)peek_data<=sector[peek_addr];
 host01_sector_engine #(.RX_TIMEOUT_CYCLES(20000),.SD_TIMEOUT_CYCLES(30000)) dut(
 .clk(clk),.reset_n(reset_n),.rx_valid(rx_valid),.rx_ready(rx_ready),.rx_data(rx_data),
 .tx_valid(tx_valid),.tx_ready(tx_ready),.tx_data(tx_data),
 .sd_start(sd_start),.sd_lba(sd_lba),.sd_busy(sd_busy),.sd_done(sd_done),
 .sd_error(sd_error),.sd_peek_addr(peek_addr),.sd_peek_data(peek_data));
 function [15:0] next_crc;
 input [15:0] old_crc;input [7:0] val;
 integer b;reg [15:0] c;
 begin
  c=old_crc;
  for(b=7;b>=0;b=b-1)
   if(c[15]^val[b])c={c[14:0],1'b0}^16'h1021;
   else c={c[14:0],1'b0};
  next_crc=c;
 end
 endfunction
 always @(posedge clk) if(reset_n && tx_valid && tx_ready)begin
  if(n>=521)$fatal(1,"HOST01 unexpected extra byte");
  received[n]<=tx_data;
  n<=n+1;
 end
 task push;
 input [7:0] v;
 begin
  @(negedge clk);rx_valid=1;rx_data=v;
  while(!rx_ready)@(negedge clk);
  @(negedge clk);rx_valid=0;
 end
 endtask
 initial begin
  for(i=0;i<512;i=i+1)sector[i]=(i ^ (i>>4) ^ 8'h5a)&8'hff;
  repeat(5)@(negedge clk);reset_n=1;tx_ready=1;
  req_crc=16'hffff;
  push(8'ha5);req_crc=next_crc(req_crc,8'ha5);
  push(8'h01);req_crc=next_crc(req_crc,8'h01);
  push(8'h40);req_crc=next_crc(req_crc,8'h40);
  push(8'h44);req_crc=next_crc(req_crc,8'h44);
  push(8'h00);req_crc=next_crc(req_crc,8'h00);
  push(8'h00);req_crc=next_crc(req_crc,8'h00);
  push(req_crc[7:0]);push(req_crc[15:8]);
  wait(sd_start);
  if(sd_lba!==32'h00004440)$fatal(1,"HOST01 wrong LBA %08x",sd_lba);
  captured_lba=sd_lba;
  @(negedge clk);sd_busy=1;
  repeat(13)@(negedge clk);
  sd_busy=0;sd_done=1;
  @(negedge clk);sd_done=0;
  wait(n==521);
  repeat(5)@(negedge clk);
  if(received[0]!==8'h5a || received[1]!==8'h81 || received[2]!==8'h00)
   $fatal(1,"HOST01 bad header");
  if({received[6],received[5],received[4],received[3]}!==captured_lba)
   $fatal(1,"HOST01 response LBA mismatch");
  check_crc=16'hffff;
  for(i=0;i<519;i=i+1)begin
   if(i>=7 && received[i]!==sector[i-7])
    $fatal(1,"HOST01 data byte %0d expected=%02x actual=%02x",i-7,sector[i-7],received[i]);
   check_crc=next_crc(check_crc,received[i]);
  end
  if({received[520],received[519]}!==check_crc)
   $fatal(1,"HOST01 CRC mismatch expect=%04x got=%02x%02x",check_crc,received[520],received[519]);
  $display("HOST01_MOCK_512_PASS: LBA=00004440 512 bytes CRC16 verified");
  $finish;
 end
 initial begin repeat(400000)@(posedge clk);$fatal(1,"HOST01 mock timeout n=%0d state=%0d",n,dut.state);end
endmodule
