// Deterministic MBR test without SD hardware. Tests partition lookup and fail-closed cases.
`timescale 1ns/1ps
module tb_sd03_mbr;
 reg clk=0;always #5 clk=~clk;
 reg reset_n=0,start=0,byte_valid=0;
 reg [8:0] byte_index=0;reg [7:0] byte_data=0;
 wire done;wire [2:0] status;wire [31:0] partition_lba,partition_sectors;
 wire [7:0] partition_type;wire [1:0] partition_index;
 reg [7:0] sector[0:511];integer i;
 sd03_mbr_parser dut(.clk(clk),.reset_n(reset_n),.start(start),
 .byte_valid(byte_valid),.byte_index(byte_index),.byte_data(byte_data),
 .done(done),.status(status),.partition_lba(partition_lba),
 .partition_sectors(partition_sectors),.partition_type(partition_type),
 .partition_index(partition_index));
 task clear_sector;begin for(i=0;i<512;i=i+1)sector[i]=0;
 sector[510]=8'h55;sector[511]=8'haa;end endtask
 task run_sector;
 input [2:0] expected_status;
 begin
 @(negedge clk);start=1;
 @(negedge clk);start=0;
 for(i=0;i<512;i=i+1)begin
   byte_index=i;byte_data=sector[i];byte_valid=1;
   @(negedge clk);
 end
 byte_valid=0;
 if(status!==expected_status || !done)
 $fatal(1,"status mismatch status=%0d expected=%0d done=%b",status,expected_status,done);
 @(negedge clk);
 end endtask
 initial begin
 repeat(3)@(negedge clk);reset_n=1;
 clear_sector();
 sector[450]=8'h0c;sector[454]=8'h00;sector[455]=8'h08;
 sector[458]=8'h00;sector[459]=8'h00;sector[460]=8'h10;
 run_sector(1);
 if(partition_lba!==32'd2048 || partition_sectors!==32'h00100000 ||
 partition_type!==8'h0c || partition_index!==0)
 $fatal(1,"FAT32 partition fields bad lba=%h size=%h",partition_lba,partition_sectors);
 clear_sector();sector[450]=8'h07;run_sector(2);
 clear_sector();sector[450]=8'hee;run_sector(4);
 clear_sector();sector[511]=0;run_sector(3);
 clear_sector();sector[450]=8'h0c;run_sector(2);
 $display("SD03_MBR_TB_PASS: FAT32 entry, no FAT32, GPT, bad signature, empty entry");
 $finish;
 end
 initial begin #200000;$fatal(1,"watchdog");end
endmodule
