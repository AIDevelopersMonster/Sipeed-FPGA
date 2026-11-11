`timescale 1ns/1ps
module tb_sync_lifo;
reg clk=0,reset_n=0,push_valid=0,pop_ready=0;
reg [7:0] push_data=0;
wire push_ready,pop_valid,full,empty,overflow,underflow;
wire [7:0] pop_data;
wire [2:0] count;
always #5 clk=~clk;
sync_lifo #(.WIDTH(8),.DEPTH(4)) dut(
 .clk(clk),.reset_n(reset_n),.push_valid(push_valid),
 .push_ready(push_ready),.push_data(push_data),
 .pop_valid(pop_valid),.pop_ready(pop_ready),.pop_data(pop_data),
 .full(full),.empty(empty),.count(count),
 .overflow(overflow),.underflow(underflow)
);
task step;
 input pv;
 input [7:0] pd;
 input pr;
 input expect_pop;
 input [7:0] expect_data;
 input integer before_count;
 begin
  @(negedge clk);push_valid=pv;push_data=pd;pop_ready=pr;
  #1;
  if(count!==before_count[2:0])$fatal(1,"LIFO count wrong");
  if(expect_pop && (!pop_valid||pop_data!==expect_data))
   $fatal(1,"LIFO expected %02x, received %02x",expect_data,pop_data);
  @(posedge clk);#1;
 end
endtask
initial begin
 repeat(3)@(negedge clk);reset_n=1;
 step(1,8'h11,0,0,0,0);
 step(1,8'h22,0,0,0,1);
 step(0,0,1,1,8'h22,2);
 step(1,8'h33,1,1,8'h11,1);
 step(0,0,1,1,8'h33,1);
 step(0,0,1,0,0,0);
 if(!underflow)$fatal(1,"LIFO underflow missing");
 step(1,8'h01,0,0,0,0);
 step(1,8'h02,0,0,0,1);
 step(1,8'h03,0,0,0,2);
 step(1,8'h04,0,0,0,3);
 if(!full)$fatal(1,"LIFO not full");
 step(1,8'h05,0,0,0,4);
 if(!overflow)$fatal(1,"LIFO overflow missing");
 step(1,8'h06,1,1,8'h04,4);
 step(0,0,1,1,8'h06,4);
 step(0,0,1,1,8'h03,3);
 step(0,0,1,1,8'h02,2);
 step(0,0,1,1,8'h01,1);
 if(!empty)$fatal(1,"LIFO not empty");
 $display("LIFO_CORE_TB_PASS: stack, full, empty, replace-top, over/underflow");
 $finish;
end
initial begin #100000;$fatal(1,"LIFO timeout");end
endmodule
