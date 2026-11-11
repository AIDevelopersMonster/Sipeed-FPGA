// SD-05 UART RX, 8N1, 2FF input synchronizer, one 27MHz clock domain.
// Samples start midpoint, then data/stop bit centers. Verilog-2005.
// SPDX-License-Identifier: MIT
module sd05_uart_rx_8n1 #(
 parameter integer CLOCK_HZ=27000000,
 parameter integer BAUD=115200,
 parameter integer DIV=(CLOCK_HZ+BAUD/2)/BAUD
)(
 input wire clk, reset_n, rx,
 output reg [7:0] data,
 output reg valid, framing_error
);
 localparam [1:0] IDLE=0, START=1, BITS=2, STOP=3;
 reg [1:0] state;
 reg rx_meta, rx_sync;
 reg [15:0] count;
 reg [2:0] bit_pos;
 reg [7:0] shift;
 always @(posedge clk or negedge reset_n) begin
   if(!reset_n)begin
     rx_meta<=1;rx_sync<=1;state<=IDLE;count<=0;
     bit_pos<=0;shift<=0;data<=0;valid<=0;framing_error<=0;
   end else begin
     rx_meta<=rx;rx_sync<=rx_meta;
     valid<=0;framing_error<=0;
     case(state)
       IDLE: if(!rx_sync)begin count<=(DIV/2)-1;state<=START;end
       START: if(count!=0) count<=count-1'b1;
              else if(!rx_sync)begin
                count<=DIV-1;bit_pos<=0;state<=BITS;
              end else state<=IDLE;
       BITS: if(count!=0)count<=count-1'b1;
             else begin
               shift[bit_pos]<=rx_sync;
               count<=DIV-1;
               if(bit_pos==7)state<=STOP;
               else bit_pos<=bit_pos+1'b1;
             end
       STOP: if(count!=0)count<=count-1'b1;
             else begin
               if(rx_sync)begin data<=shift;valid<=1;end
               else framing_error<=1;
               state<=IDLE;
             end
       default:state<=IDLE;
     endcase
   end
 end
endmodule
