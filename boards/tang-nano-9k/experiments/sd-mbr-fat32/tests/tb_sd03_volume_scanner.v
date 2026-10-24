// End-to-end SD-03 scanner behavioral test with a synchronous sector RAM model.
// Verifies LBA0 -> MBR -> partition VBR and superfloppy, GPT, invalid BPB.
// Model only; no FPGA timing, SPI electrical simulation, or card writes.
`timescale 1ns/1ps
module tb_sd03_volume_scanner;
reg clk=0;always #5 clk=~clk;
reg reset_n=0,start=0,sd_busy=0,sd_done=0;
reg [7:0] sd_error=0;
wire sd_start;wire [31:0] sd_lba;
wire [8:0] peek_addr;reg [7:0] peek_data=0;
wire done;wire [3:0] result;
wire [31:0] volume_lba,fat_lba,data_lba,root_lba,cluster_count;
reg [31:0] selected_lba=0;
integer mode=0,reads=0,delay_count=0,timeout=0;
sd03_volume_scanner dut(
.clk(clk),.reset_n(reset_n),.start(start),
.sd_start(sd_start),.sd_lba(sd_lba),
.sd_busy(sd_busy),.sd_done(sd_done),.sd_error(sd_error),
.peek_addr(peek_addr),.peek_data(peek_data),
.done(done),.result(result),.volume_lba(volume_lba),
.fat_lba(fat_lba),.data_lba(data_lba),
.root_lba(root_lba),.cluster_count(cluster_count));

function [7:0] bpb;
input [8:0] a;
begin
bpb=0;
case(a)
0:bpb=8'heb;
11:bpb=8'h00;12:bpb=8'h02;
13:bpb=(mode==3)?8'd3:8'd8;
14:bpb=8'd32;
16:bpb=8'd2;
32:bpb=8'h00;33:bpb=8'h00;34:bpb=8'h10;
36:bpb=8'h00;37:bpb=8'h04;
44:bpb=8'h02;48:bpb=8'h01;50:bpb=8'h06;
510:bpb=8'h55;511:bpb=8'haa;
default:bpb=0;
endcase
end
endfunction
function [7:0] mbr;
input [8:0] a;
begin
mbr=0;
case(a)
450:mbr=(mode==2)?8'hee:8'h0c;
454:mbr=8'h00;
455:mbr=8'h08;
458:mbr=8'h00;459:mbr=8'h00;460:mbr=8'h10;
510:mbr=8'h55;511:mbr=8'haa;
default:mbr=0;
endcase
end
endfunction
function [7:0] image_byte;
input [31:0] lba;
input [8:0] a;
begin
if(mode==1)image_byte=(lba==0)?bpb(a):8'hff;
else if(lba==0)image_byte=mbr(a);
else if(lba==2048)image_byte=bpb(a);
else image_byte=8'hff;
end
endfunction

always @(posedge clk) begin
 peek_data <= image_byte(selected_lba,peek_addr);
 if(!reset_n)begin
  selected_lba<=0;reads<=0;delay_count<=0;sd_done<=0;sd_busy<=0;
 end else begin
  sd_done<=0;
  if(sd_start && !sd_busy)begin
    selected_lba<=sd_lba;
    reads<=reads+1;
    sd_busy<=1;
    delay_count<=3;
  end else if(sd_busy)begin
    if(delay_count==0)begin
      sd_busy<=0;
      sd_done<=1;
    end else delay_count<=delay_count-1;
  end
 end
end

task run;
input integer scenario;
input [3:0] expected;
input integer count;
begin
@(negedge clk);reset_n=0;mode=scenario;
repeat(3)@(negedge clk);reset_n=1;
@(negedge clk);start=1;
@(negedge clk);start=0;
timeout=0;
while(!done && timeout<4000)begin
 @(negedge clk);timeout=timeout+1;
end
if(!done || result!==expected || reads!==count)
 $fatal(1,"scan mode=%0d result=%0d expected=%0d reads=%0d expected=%0d timeout=%0d",
 scenario,result,expected,reads,count,timeout);
if(expected==1 && (volume_lba!==2048 || fat_lba!==2080 ||
                    data_lba!==4128 || root_lba!==4128 ||
                    cluster_count!==130812))
 $fatal(1,"MBR->BPB arithmetic incorrect");
if(expected==2 && (volume_lba!==0 || fat_lba!==32 || data_lba!==2080))
 $fatal(1,"superfloppy arithmetic incorrect");
@(negedge clk);
end
endtask
initial begin
run(0,1,2); // MBR partition followed by valid FAT32 VBR
run(1,2,1); // BPB in LBA0, superfloppy
run(2,3,1); // protective GPT, no FAT32 claim
run(3,6,2); // MBR FAT32 candidate but invalid cluster geometry
$display("SD03_SCANNER_TB_PASS: two-stage MBR/FAT32, superfloppy, GPT, invalid BPB");
$finish;
end
initial begin #1000000;$fatal(1,"watchdog");end
endmodule
