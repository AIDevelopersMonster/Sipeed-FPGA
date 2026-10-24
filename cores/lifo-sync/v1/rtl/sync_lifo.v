// Synchronous fixed-depth LIFO stack.
// Simultaneous accepted push+pop replaces the old top in one clock;
// pop_data still represents the OLD top for that transaction.
// Empty stack never has pop_valid, even if push_valid=1.
// SPDX-License-Identifier: MIT
module sync_lifo #(
 parameter integer WIDTH=8,
 parameter integer DEPTH=8
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
 localparam integer COUNT_W=log2ceil(DEPTH+1);
 reg [COUNT_W-1:0] count_reg;
 reg [WIDTH-1:0] memory[0:DEPTH-1];
 assign count=count_reg;
 assign full=(count_reg==DEPTH);
 assign empty=(count_reg==0);
 assign pop_valid=!empty;
 assign push_ready=!full || (pop_ready && pop_valid);
 assign pop_data=empty?{WIDTH{1'b0}}:memory[count_reg-1'b1];
 wire do_push=push_valid && push_ready;
 wire do_pop=pop_valid && pop_ready;
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin
   count_reg<=0;overflow<=0;underflow<=0;
  end else begin
   overflow<=push_valid && !push_ready;
   underflow<=pop_ready && !pop_valid;
   case({do_push,do_pop})
    2'b10:begin
     memory[count_reg]<=push_data;
     count_reg<=count_reg+1'b1;
    end
    2'b01:count_reg<=count_reg-1'b1;
    2'b11:memory[count_reg-1'b1]<=push_data;
    default:begin end
   endcase
  end
 end
endmodule
