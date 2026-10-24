// Synchronous single-clock FIFO with valid/ready interface.
// A full FIFO accepts a push when a pop is accepted in the same cycle.
// An empty FIFO does not bypass push_data directly to the consumer.
// SPDX-License-Identifier: MIT
module sync_fifo #(
 parameter integer WIDTH=8,
 parameter integer DEPTH=8,
 // The port list must know this width during Verilog-2005 elaboration.
 // Derived parameter; normally leave unchanged when overriding DEPTH.
 parameter integer COUNT_W=(DEPTH>1)?$clog2(DEPTH+1):1
)(
 input wire clk,input wire reset_n,
 input wire push_valid,output wire push_ready,input wire [WIDTH-1:0] push_data,
 output wire pop_valid,input wire pop_ready,output wire [WIDTH-1:0] pop_data,
 output wire full,output wire empty,output wire [COUNT_W-1:0] count,
 output reg overflow,output reg underflow
);
 function integer log2ceil;
 input integer x;
 integer v;
 begin
  v=x-1;
  for(log2ceil=0;v>0;log2ceil=log2ceil+1)v=v>>1;
 end
 endfunction
 localparam integer PW=(DEPTH>2)?log2ceil(DEPTH):1;
 reg [PW-1:0] write_ptr,read_ptr;
 reg [COUNT_W-1:0] count_reg;
 reg [WIDTH-1:0] memory[0:DEPTH-1];
 assign count=count_reg;
 assign full=(count_reg==DEPTH);
 assign empty=(count_reg==0);
 assign pop_valid=!empty;
 assign push_ready=!full || (pop_ready && pop_valid);
 assign pop_data=empty?{WIDTH{1'b0}}:memory[read_ptr];
 wire do_push=push_valid && push_ready;
 wire do_pop=pop_valid && pop_ready;
 function [PW-1:0] advance;
 input [PW-1:0] ptr;
 begin
  if(ptr==DEPTH-1)advance={PW{1'b0}};
  else advance=ptr+1'b1;
 end
 endfunction
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin
   write_ptr<=0;read_ptr<=0;count_reg<=0;overflow<=0;underflow<=0;
  end else begin
   overflow<=push_valid && !push_ready;
   underflow<=pop_ready && !pop_valid;
   if(do_push)begin
    memory[write_ptr]<=push_data;
    write_ptr<=advance(write_ptr);
   end
   if(do_pop)read_ptr<=advance(read_ptr);
   case({do_push,do_pop})
    2'b10:count_reg<=count_reg+1'b1;
    2'b01:count_reg<=count_reg-1'b1;
    default:begin end
   endcase
  end
 end
endmodule
