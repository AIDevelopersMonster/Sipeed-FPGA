`timescale 1ns/1ps
// Standalone TX <-> RX test, no SDHC, PicoRV32 or HOST protocol.
module tb_uart_loopback;
reg clk=0,reset_n=0,start=0;
reg [7:0] data=0;
wire tx,busy,valid,framing_error;
wire [7:0] received;
integer count=0;
always #5 clk=~clk;
uart_tx_8n1 #(.CLOCK_HZ(400),.BAUD(20)) uut_tx(
 .clk(clk),.reset_n(reset_n),.start(start),.data(data),.tx(tx),.busy(busy)
);
uart_rx_8n1 #(.CLOCK_HZ(400),.BAUD(20)) uut_rx(
 .clk(clk),.reset_n(reset_n),.rx(tx),.data(received),
 .valid(valid),.framing_error(framing_error)
);
always @(posedge clk) if(reset_n)begin
 if(framing_error)$fatal(1,"UART_LOOPBACK: framing error");
 if(valid)begin
  case(count)
   0:if(received!==8'h55)$fatal(1,"UART_LOOPBACK: byte 0 wrong");
   1:if(received!==8'ha5)$fatal(1,"UART_LOOPBACK: byte 1 wrong");
   2:if(received!==8'h00)$fatal(1,"UART_LOOPBACK: byte 2 wrong");
   3:if(received!==8'hff)$fatal(1,"UART_LOOPBACK: byte 3 wrong");
   4:if(received!==8'h0d)$fatal(1,"UART_LOOPBACK: byte 4 wrong");
   default:$fatal(1,"UART_LOOPBACK: unexpected byte");
  endcase
  count=count+1;
 end
end
task send_byte;
 input [7:0] b;
 begin
  @(negedge clk);
  while(busy)@(negedge clk);
  data=b;start=1;
  @(negedge clk);start=0;
  wait(busy);
  wait(!busy);
  repeat(3)@(negedge clk);
 end
endtask
initial begin
 repeat(8)@(negedge clk);reset_n=1;
 send_byte(8'h55);send_byte(8'ha5);send_byte(8'h00);
 send_byte(8'hff);send_byte(8'h0d);
 repeat(20)@(negedge clk);
 if(count!==5)$fatal(1,"UART_LOOPBACK: received %0d bytes",count);
 if(tx!==1'b1||busy!==1'b0)$fatal(1,"UART_LOOPBACK: TX not idle");
 $display("UART_CORE_LOOPBACK_PASS: 5 bytes, TX/RX 8N1, no framing error");
 $finish;
end
initial begin #1000000;$fatal(1,"UART_LOOPBACK: timeout");end
endmodule
