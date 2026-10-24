// SD-03 BPB positive/negative behavioral acceptance; Verilog-2005.
`timescale 1ns/1ps
module tb_sd03_fat32_bpb;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,start=0,byte_valid=0;
reg [31:0] volume_lba=2048,partition_sectors=1048576;
reg [8:0] byte_index=0;reg [7:0] byte_data=0;
wire done;wire [2:0] status;
wire [31:0] fat_lba,data_lba,root_lba,cluster_count,total_sectors,fat_sectors,root_cluster;
wire [7:0] sectors_per_cluster;
reg [7:0] sector[0:511];integer i;
sd03_fat32_bpb dut(
.clk(clk),.reset_n(reset_n),.start(start),.volume_lba(volume_lba),
.partition_sectors(partition_sectors),.byte_valid(byte_valid),.byte_index(byte_index),
.byte_data(byte_data),.done(done),.status(status),.fat_lba(fat_lba),
.data_lba(data_lba),.root_lba(root_lba),.cluster_count(cluster_count),
.total_sectors(total_sectors),.fat_sectors(fat_sectors),.root_cluster(root_cluster),
.sectors_per_cluster(sectors_per_cluster));
task good_sector;
begin
for(i=0;i<512;i=i+1)sector[i]=0;
sector[0]=8'heb;
sector[11]=8'h00;sector[12]=8'h02; // 512 bytes
sector[13]=8'd8; // eight sectors per cluster
sector[14]=8'd32; // reserved
sector[16]=8'd2; // FAT copies
sector[32]=8'h00;sector[33]=8'h00;sector[34]=8'h10; // 0x00100000 sectors
sector[36]=8'h00;sector[37]=8'h04; // 1024 sectors per FAT => enough entries
sector[44]=8'h02; // root cluster 2
sector[48]=8'h01; // FSInfo sector
sector[50]=8'h06; // backup VBR sector
sector[510]=8'h55;sector[511]=8'haa;
end
endtask
task run_sector;
input [2:0] expected;
begin
@(negedge clk);start=1;
@(negedge clk);start=0;
for(i=0;i<512;i=i+1)begin
byte_index=i;byte_data=sector[i];byte_valid=1;
@(negedge clk);
end
byte_valid=0;
begin : await_bpb
integer ticks;
ticks=0;
while(!done && ticks<100)begin
  @(negedge clk);
  ticks=ticks+1;
end
end
if(status!==expected || !done)
$fatal(1,"BPB status got=%0d expected=%0d done=%b",status,expected,done);
@(negedge clk);
end
endtask
initial begin
repeat(3)@(negedge clk);reset_n=1;
good_sector();run_sector(1);
if(fat_lba!==2080 || data_lba!==4128 || root_lba!==4128 ||
cluster_count!==130812 || total_sectors!==1048576 ||
sectors_per_cluster!==8)
$fatal(1,"BPB LBA arithmetic error FAT=%0d DATA=%0d ROOT=%0d CLUS=%0d",
fat_lba,data_lba,root_lba,cluster_count);
good_sector();sector[13]=3;run_sector(3); // not power of two
good_sector();sector[511]=0;run_sector(2);
good_sector();sector[36]=1;sector[37]=0;run_sector(5); // FAT too small
good_sector();sector[32]=8'h00;sector[33]=8'h00;sector[34]=8'h20;run_sector(4); // beyond partition
good_sector();sector[3]="E";sector[4]="X";sector[5]="F";sector[6]="A";
sector[7]="T";sector[8]=" ";sector[9]=" ";sector[10]=" ";run_sector(6);
good_sector();volume_lba=0;partition_sectors=0;run_sector(1); // superfloppy VBR
if(fat_lba!==32 || data_lba!==2080 || root_lba!==2080)
$fatal(1,"superfloppy base arithmetic");
$display("SD03_FAT32_BPB_TB_PASS: valid, superfloppy, invalid geometry, CRC-independent rejection");
$finish;
end
initial begin #200000;$fatal(1,"timeout");end
endmodule
