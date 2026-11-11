`timescale 1ns/1ps
module tb_sync_fifo;
reg clk=0,reset_n=0,push_valid=0,pop_ready=0;
reg [7:0] push_data=0;
wire push_ready,pop_valid,full,empty,overflow,underflow;
wire [7:0] pop_data;
wire [2:0] count;
always #5 clk=~clk;
sync_fifo #(.WIDTH(8),.DEPTH(4)) dut(
 .clk(clk),.reset_n(reset_n),.push_valid(push_valid),
 .push_ready(push_ready),.push_data(push_data),
 .pop_valid(pop_valid),.pop_ready(pop_ready),.pop_data(pop_data),
 .full(full),.empty(empty),.count(count),
 .overflow(overflow),.underflow(underflow)
);
task step;
 input push_req;
 input [7:0] val;
 input pop_req;
 input expect_pop;
 input [7:0] expect_data;
 input integer expect_count;
 begin
  @(negedge clk);push_valid=push_req;push_data=val;pop_ready=pop_req;
  #1;
  if(expect_pop && (!pop_valid || pop_data!==expect_data))
   $fatal(1,"FIFO: expected top %02x, got valid=%b data=%02x",expect_data,pop_valid,pop_data);
  if(count!==expect_count[2:0])
   $fatal(1,"FIFO: before count=%0d expected=%0d",count,expect_count);
  @(posedge clk);#1;
 end
endtask
initial begin
 repeat(3)@(negedge clk);reset_n=1;
 step(1,8'h41,0,0,0,0);
 step(1,8'h42,0,0,0,1);
 step(0,0,1,1,8'h41,2);
 step(1,8'h43,1,1,8'h42,1);
 step(0,0,1,1,8'h43,1);
 step(0,0,1,0,0,0);
 if(!underflow)$fatal(1,"FIFO: underflow not detected");
 step(1,8'h10,0,0,0,0);
 step(1,8'h11,0,0,0,1);
 step(1,8'h12,0,0,0,2);
 step(1,8'h13,0,0,0,3);
 if(!full)$fatal(1,"FIFO: should be full");
 step(1,8'hff,0,0,0,4);
 if(!overflow)$fatal(1,"FIFO: overflow not detected");
 step(1,8'h20,1,1,8'h10,4);
 step(0,0,1,1,8'h11,4);
 step(0,0,1,1,8'h12,3);
 step(0,0,1,1,8'h13,2);
 step(0,0,1,1,8'h20,1);
 if(!empty)$fatal(1,"FIFO: not empty after drain");
 $display("FIFO_CORE_TB_PASS: ordering, wrap, full, empty, simultaneous, over/underflow");
 $finish;
end
initial begin #100000;$fatal(1,"FIFO: timeout");end
endmodule
