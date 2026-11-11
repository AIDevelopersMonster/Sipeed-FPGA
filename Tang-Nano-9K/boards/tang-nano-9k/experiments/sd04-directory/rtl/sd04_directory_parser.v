// SD-04.1 read-only FAT32 8.3 directory entry decoder.
// Each entry is 32 consecutive bytes from one sector. Byte index 0..511,
// byte_valid must remain asserted exactly once for every delivered byte.
// Output reports ordinary short-file entries only; LFN is classified separately.
// SPDX-License-Identifier: MIT
module sd04_directory_parser(
 input wire clk,input wire reset_n,input wire start,
 input wire byte_valid,input wire [8:0] byte_index,input wire [7:0] byte_data,
 output reg entry_valid,output reg [3:0] kind,
 output reg [7:0] entry_index,output reg [87:0] short_name,
 output reg [7:0] attributes,output reg [31:0] first_cluster,
 output reg [31:0] file_size, output reg sector_done
);
 // kind: 1 file, 2 directory, 3 LFN, 4 deleted, 5 unused terminator,
 // 6 volume label; only 1 and 2 are normal 8.3 objects.
 reg active,terminated;
 reg [7:0] name_byte0,attr,lo0,lo1,hi0,hi1,size0,size1,size2,size3;
 reg [87:0] name_buf;
 wire [4:0] off=byte_index[4:0];
 always @(posedge clk or negedge reset_n) begin
  if(!reset_n) begin
   active<=0;terminated<=0;entry_valid<=0;kind<=0;
   sector_done<=0;entry_index<=0;short_name<=0;attributes<=0;
   first_cluster<=0;file_size<=0;
   name_byte0<=0;attr<=0;lo0<=0;lo1<=0;hi0<=0;hi1<=0;
   size0<=0;size1<=0;size2<=0;size3<=0;name_buf<=0;
  end else begin
   entry_valid<=0;sector_done<=0;
   if(start)begin active<=1;terminated<=0;kind<=0;end
   else if(active&&byte_valid)begin
    if(off==0)name_byte0<=byte_data;
    if(off<=10)name_buf[(10-off)*8 +: 8]<=byte_data;
    case(off)
     11:attr<=byte_data;
     20:hi0<=byte_data;21:hi1<=byte_data;
     26:lo0<=byte_data;27:lo1<=byte_data;
     28:size0<=byte_data;29:size1<=byte_data;
     30:size2<=byte_data;31:size3<=byte_data;
     default:begin end
    endcase
    if(off==31 && !terminated)begin
     entry_valid<=1;entry_index<=byte_index[8:5];
     short_name<=name_buf;attributes<=attr;
     first_cluster<={hi1,hi0,lo1,lo0};
     file_size<={size3,size2,size1,size0};
     if(name_byte0==8'h00)begin kind<=5;terminated<=1;end
     else if(name_byte0==8'he5)kind<=4;
     else if((attr&8'h3f)==8'h0f)kind<=3;
     else if(attr[3])kind<=6;
     else if(attr[4])kind<=2;
     else kind<=1;
    end
    if(byte_index==511)begin sector_done<=1;active<=0;end
   end
  end
 end
endmodule
