`timescale 1ns/1ps
module tb_crc16_ccitt;
 reg [15:0] crc=16'hffff;
 reg [7:0] byte_in=0;
 wire [15:0] crc_out;
 integer i;
 reg [71:0] ascii_test="123456789";
 crc16_ccitt_byte dut(.crc_in(crc),.byte_in(byte_in),.crc_out(crc_out));
 initial begin
  for(i=0;i<9;i=i+1)begin
   byte_in=ascii_test[(8-i)*8+:8];
   #1; crc=crc_out;
  end
  if(crc!==16'h29b1)$fatal(1,"CRC16 test vector fail: %04x",crc);
  $display("HOST01_CRC16_PASS: CCITT-FALSE 123456789 -> 29B1");
  $finish;
 end
endmodule
