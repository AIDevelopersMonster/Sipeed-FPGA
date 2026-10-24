// CRC-16/CCITT-FALSE single-byte combinational update.
// Polynomial 0x1021, init 0xFFFF, no reflection, xorout=0.
// Independent core: CRC context/register is owned by caller.
// SPDX-License-Identifier: MIT
module crc16_ccitt_byte(
 input wire [15:0] crc_in,
 input wire [7:0] byte_in,
 output reg [15:0] crc_out
);
 integer i;
 reg [15:0] temp;
 always @* begin
  temp=crc_in;
  for(i=7;i>=0;i=i-1)begin
   if(temp[15] ^ byte_in[i]) temp={temp[14:0],1'b0} ^ 16'h1021;
   else temp={temp[14:0],1'b0};
  end
  crc_out=temp;
 end
endmodule
