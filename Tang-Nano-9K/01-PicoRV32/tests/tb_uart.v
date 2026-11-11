`timescale 1ns/1ps
module tb_uart;
  reg clk=0, reset_n=0, start=0;
  reg [7:0] data=8'h00;
  wire tx, busy;
  uart_tx_8n1 #(.CLOCK_HZ(100), .BAUD(10)) dut (
    .clk(clk),.reset_n(reset_n),.start(start),.data(data),.tx(tx),.busy(busy));
  always #5 clk=~clk;
  integer i;
  reg [9:0] expected;
  initial begin
    expected={1'b1,8'ha5,1'b0};
    repeat(3) @(negedge clk);
    reset_n=1;
    fork
      begin : decode
        @(negedge tx);
        for(i=0;i<10;i=i+1) begin
          #50;  // Midpoint of bit: divider = 10 clock periods of 10 ns.
          if(tx !== expected[i]) begin
            $display("UART FAIL: bit %0d expected %0b got %0b",i,expected[i],tx);
            $fatal(1);
          end
          #50;
        end
        repeat(2) @(negedge clk);
        if(busy !== 0 || tx !== 1) $fatal(1,"UART FAIL: not idle");
        $display("UART TB PASS: transmitted 0xA5 as 8N1");
      end
      begin : drive
        @(negedge clk); data=8'ha5; start=1;
        @(negedge clk); start=0;
      end
    join
    $finish;
  end
  initial begin #100000; $fatal(1,"UART FAIL: timeout"); end
endmodule
