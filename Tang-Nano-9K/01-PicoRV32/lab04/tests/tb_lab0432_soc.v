// LAB-04.3.2 minimal real-PicoRV32 CPU+ROM+RAM+UART integration smoke.
// Uses pinned repo vendor/picorv32/picorv32.v (not a behavioral CPU stub).
// Send LED 3 + CR at 115200; verify CPU updates actual LED MMIO register.
// Run with simulation cwd lab04/rtl so lab04_boot.hex can be read.
`timescale 1ns/1ps
module tb_lab0432_soc;
  reg clk=0, reset_n=0, rx=1;
  always #18.5 clk=~clk;
  wire tx;
  wire [5:0] led_n, mask;
  wire video_wr_valid;
  wire [3:0] video_wr_index;
  wire [23:0] video_wr_value;
  integer commits=0;
  lab04_cpu_soc dut (
    .clk(clk), .reset_n(reset_n), .uart_rx(rx), .uart_tx(tx),
    .led_n(led_n), .led_mask_sys(mask),
    .video_wr_valid(video_wr_valid), .video_wr_ready(1'b1),
    .video_wr_index(video_wr_index), .video_wr_value(video_wr_value)
  );
  always @(posedge clk)
    if (video_wr_valid && video_wr_index==4'd15) commits<=commits+1;
  task send_byte;
    input [7:0] byte_to_send;
    integer i;
    begin
      @(negedge clk);rx=0;
      repeat (234) @(posedge clk);
      for(i=0;i<8;i=i+1) begin
        @(negedge clk);rx=byte_to_send[i];
        repeat (234) @(posedge clk);
      end
      @(negedge clk);rx=1;
      repeat (234) @(posedge clk);
    end
  endtask
  initial begin
    repeat (30) @(posedge clk);
    @(negedge clk);reset_n=1;
    // Let the UART banner and command prompt finish; UART has no RTS/CTS.
    repeat (470000) @(posedge clk);
    if (mask !== 6'b0) $fatal(1,"Initial LED mask not zero");
    if (dut.video_shadow[0] !== 24'd100 || dut.video_shadow[8] !== 24'd280)
      $fatal(1,"Default in-canvas object coordinates missing");
    if (commits<1) $fatal(1,"Initial video commit missing");
    send_byte(8'h6c); // 'l'
    send_byte(8'h65); // 'e'
    send_byte(8'h64); // 'd'
    send_byte(8'h20); // ' '
    send_byte(8'h33); // '3'
    send_byte(8'h0d); // CR submits command
    repeat (200000) @(posedge clk);
    if (mask !== 6'b000111 || led_n !== 6'b111000)
      $fatal(1,"LED 3 command not executed by real CPU, mask=%h",mask);
    if (dut.shell_ram[0] !== 32'h4c || dut.shell_ram[1] !== 32'h45 ||
        dut.shell_ram[2] !== 32'h44)
      $fatal(1,"CPU RAM line buffer not populated");
    $display("LAB0432_SOC_RTL_PASS: real PicoRV32, sync ROM/RAM, UART command LED 3");
    $finish;
  end
  initial begin
    #45000000;
    $fatal(1,"LAB0432_SOC_RTL_TIMEOUT");
  end
endmodule
