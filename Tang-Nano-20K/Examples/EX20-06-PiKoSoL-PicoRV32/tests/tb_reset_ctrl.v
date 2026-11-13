`timescale 1ns/1ps
// Asynchronous assertion and per-domain synchronized release test.
module tb_reset_ctrl;
  reg clk27=0, serial_clk=0, pix_clk=0, pll_locked=0, reset_btn=0;
  always #18.5 clk27=~clk27;
  always #1.35 serial_clk=~serial_clk;
  always #6.75 pix_clk=~pix_clk;
  wire resetn_cpu,resetn_pixel,resetn_serializer;
  pikosol20k_reset_ctrl #(.POR_BITS(4)) dut(
    .clk27(clk27),.pix_clk(pix_clk),
    .pll_locked(pll_locked),.reset_btn(reset_btn),
    .resetn_cpu(resetn_cpu),.resetn_pixel(resetn_pixel),
    .resetn_serializer(resetn_serializer)
  );
  initial begin
    repeat(5) @(negedge clk27);
    if ({resetn_cpu,resetn_serializer,resetn_pixel} !== 3'b000)
      $fatal(1,"Initial reset incorrect");
    pll_locked=1;
    #0.2;
    if (resetn_serializer !== 1) $fatal(1,"Vendor HDMI reset did not follow PLL LOCK");
    if (resetn_cpu !== 0 || resetn_pixel !== 0)
      $fatal(1,"CPU/pixel reset released without qualification");
    repeat(30) @(negedge clk27);
    if ({resetn_cpu,resetn_pixel} !== 2'b11)
      $fatal(1,"CPU or pixel reset not released");
    pll_locked=0;
    #0.2;
    if ({resetn_cpu,resetn_serializer,resetn_pixel} !== 3'b000)
      $fatal(1,"PLL loss failed to reset all domains");
    repeat(2) @(negedge clk27);
    pll_locked=1;
    repeat(30) @(negedge clk27);
    if ({resetn_cpu,resetn_pixel} !== 2'b11)
      $fatal(1,"Recovery from PLL loss failed");
    reset_btn=1;
    #0.2;
    if ({resetn_cpu,resetn_serializer,resetn_pixel} !== 3'b000)
      $fatal(1,"Button failed to assert reset");
    repeat(2) @(negedge clk27);
    reset_btn=0;
    repeat(30) @(negedge clk27);
    if ({resetn_cpu,resetn_pixel} !== 2'b11)
      $fatal(1,"Recovery from button failed");
    $display("PIKOSOL20K_RESET_SIM_PASS");
    $finish;
  end
endmodule
