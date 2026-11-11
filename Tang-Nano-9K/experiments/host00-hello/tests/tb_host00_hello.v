`timescale 1ns/1ps
module tb_host00_hello;
reg clk=0,reset_n=0,rx=1;
wire tx;
wire [7:0] received;
wire valid,error;
integer got=0;
always #5 clk=~clk;
host00_uart_hello_top dut(.clk(clk),.reset_n(reset_n),.uart_rx(rx),.uart_tx(tx));
uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) observer(
 .clk(clk),.reset_n(reset_n),.rx(tx),.data(received),
 .valid(valid),.framing_error(error));
always @(posedge clk)if(reset_n)begin
 if(error)$fatal(1,"HOST00 framing error");
 if(valid)begin
  case(got)
   0:if(received!=="H")$fatal(1,"response 0");
   1:if(received!=="E")$fatal(1,"response 1");
   2:if(received!=="L")$fatal(1,"response 2");
   3:if(received!=="L")$fatal(1,"response 3");
   4:if(received!=="O")$fatal(1,"response 4");
   5:if(received!==8'h0a)$fatal(1,"response newline");
   default:$fatal(1,"extra output");
  endcase
  got=got+1;
 end
end
task send_byte;
input [7:0] b;
integer i;
begin
 @(negedge clk);rx=0;
 repeat(234)@(negedge clk);
 for(i=0;i<8;i=i+1)begin rx=b[i];repeat(234)@(negedge clk);end
 rx=1;repeat(234)@(negedge clk);
end
endtask
initial begin
 repeat(10)@(negedge clk);reset_n=1;
 send_byte("H");
 wait(got==6);
 repeat(250)@(negedge clk);
 if(dut.rx_overflow||dut.tx_overflow)$fatal(1,"queue overflow");
 $display("HOST00_HELLO_TB_PASS: UART RX -> FIFO -> handler -> FIFO -> UART TX");
 $finish;
end
initial begin repeat(20000)@(posedge clk);$fatal(1,"HOST00 timeout: got=%0d",got);end
endmodule
