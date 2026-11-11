// HOST-00 lab command handler: one-byte 'H' request -> "HELLO\n".
// Decoupled byte handshake. No UART electrical logic, no SD/FS logic.
module host00_hello(
 input wire clk,input wire reset_n,
 input wire rx_valid,output wire rx_ready,input wire [7:0] rx_data,
 output reg tx_valid,input wire tx_ready,output reg [7:0] tx_data
);
 reg [2:0] idx;
 reg active;
 assign rx_ready=!active;
 function [7:0] c;
 input [2:0] n;
 begin case(n)
  0:c="H";1:c="E";2:c="L";3:c="L";4:c="O";5:c=8'h0a;
  default:c="?";
 endcase end
 endfunction
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin active<=0;idx<=0;tx_valid<=0;tx_data<=0;end
  else begin
   if(!active && rx_valid && rx_ready && rx_data=="H")begin
    active<=1;idx<=0;tx_valid<=1;tx_data<="H";
   end else if(active && tx_valid && tx_ready)begin
    if(idx==5)begin active<=0;tx_valid<=0;end
    else begin idx<=idx+1'b1;tx_data<=c(idx+1'b1);end
   end
  end
 end
endmodule
