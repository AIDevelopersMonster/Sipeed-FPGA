`timescale 1ns/1ps
module tb_sd04_directory;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,start=0,byte_valid=0;
reg [8:0] byte_index=0;reg [7:0] byte_data=0;
wire entry_valid,sector_done;wire [3:0] kind;wire [7:0] entry_index,attributes;
wire [87:0] short_name;wire [31:0] first_cluster,file_size;
reg [7:0] sector[0:511];
integer i,n=0;
sd04_directory_parser dut(.clk(clk),.reset_n(reset_n),.start(start),
 .byte_valid(byte_valid),.byte_index(byte_index),.byte_data(byte_data),
 .entry_valid(entry_valid),.kind(kind),.entry_index(entry_index),
 .short_name(short_name),.attributes(attributes),.first_cluster(first_cluster),
 .file_size(file_size),.sector_done(sector_done));
always @(negedge clk)if(entry_valid)begin
 if(n==0 && (kind!==1 || short_name!=="README  TXT" || first_cluster!==32'd5 || file_size!==32'd1234))
   $fatal(1,"file wrong kind=%0d name=%s cluster=%0d size=%0d",kind,short_name,first_cluster,file_size);
 if(n==1 && kind!==2)$fatal(1,"directory kind");
 if(n==2 && kind!==3)$fatal(1,"LFN classification");
 if(n==3 && kind!==4)$fatal(1,"deleted classification");
 if(n==4 && kind!==5)$fatal(1,"terminator classification");
 n=n+1;
end
initial begin
 for(i=0;i<512;i=i+1)sector[i]=0;
 sector[0]="R";sector[1]="E";sector[2]="A";sector[3]="D";sector[4]="M";sector[5]="E";
 sector[6]=" ";sector[7]=" ";sector[8]="T";sector[9]="X";sector[10]="T";
 sector[11]=8'h20;sector[26]=5;sector[28]=8'hd2;sector[29]=8'h04;
 sector[32]="F";sector[43]=8'h10;
 sector[64]="L";sector[75]=8'h0f;
 sector[96]=8'he5;
 repeat(3)@(negedge clk);reset_n=1;
 @(negedge clk);start=1;
 @(negedge clk);start=0;
 for(i=0;i<512;i=i+1)begin
  byte_index=i;byte_data=sector[i];byte_valid=1;
  @(negedge clk);
 end
 byte_valid=0;
 if(n!=5 || !sector_done)$fatal(1,"count=%0d done=%b",n,sector_done);
 $display("SD04_DIRECTORY_TB_PASS: file, directory, LFN, deleted, terminator");
 $finish;
end
initial begin #200000;$fatal(1,"timeout");end
endmodule
