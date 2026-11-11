`timescale 1ns/1ps
module tb_soc;
  reg clk=0, reset_n=0, rx=1;
  wire tx;
  wire [5:0] led_n;
  picorv32_soc dut(.clk(clk),.reset_n(reset_n),.uart_rx(rx),.uart_tx(tx),.led_n(led_n));
  always #5 clk=~clk; // Accelerated test clock, UART divider still in clock cycles.
  reg [7:0] msg [0:4];
  integer count=0;
  always @(posedge clk) begin
    if(reset_n && dut.tx_start) begin
      if(count>=5) $fatal(1,"SOC FAIL: excessive UART bytes");
      msg[count]=dut.tx_byte;
      count=count+1;
    end
    if(reset_n && dut.cpu_trap) $fatal(1,"SOC FAIL: CPU trapped");
  end
  initial begin
    repeat(10) @(negedge clk); reset_n=1;
    repeat(25000) @(negedge clk);
    if(dut.test_status !== 32'h600dcafe) $fatal(1,"SOC FAIL: firmware did not finish");
    if(count!=5) $fatal(1,"SOC FAIL: expected 5 UART bytes, got %0d", count);
    if(msg[0]!==8'h50 || msg[1]!==8'h49 || msg[2]!==8'h43 ||
       msg[3]!==8'h4f || msg[4]!==8'h0a) $fatal(1,"SOC FAIL: UART was not PICO\\n");
    $display("SOC TB PASS: RV32I boot, MMIO signature, five UART bytes, status 600DCAFE");
    $finish;
  end
  initial begin #500000; $fatal(1,"SOC FAIL: timeout"); end
endmodule
