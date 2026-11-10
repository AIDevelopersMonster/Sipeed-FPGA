`timescale 1ns/1ps
// PiKoSoL 20K native renderer smoke test. Does not simulate Gowin TMDS IP.
module tb_renderer;
  reg clk_pixel=0, clk_cpu=0, resetn_pixel=0, resetn_cpu=0;
  always #5 clk_pixel=~clk_pixel;
  always #18 clk_cpu=~clk_cpu;
  reg de=0;
  reg [10:0] px=0;
  reg [9:0] py=0;
  reg char_valid=0;
  reg [7:0] char_data=0;
  wire char_ready;
  reg gfx_valid=0;
  reg [5:0] gfx_index=0;
  reg [23:0] gfx_value=0;
  reg [5:0] leds=0;
  wire [23:0] bgr_out;
  pikosol20k_renderer dut(
    .pix_clk(clk_pixel),.resetn_pixel(resetn_pixel),
    .de(de),.px(px),.py(py),
    .char_valid(char_valid),.char_ready(char_ready),.char_data(char_data),
    .cpu_clk(clk_cpu),.resetn_cpu(resetn_cpu),
    .gfx_valid(gfx_valid),.gfx_index(gfx_index),.gfx_value(gfx_value),
    .leds(leds),.bgr_out(bgr_out)
  );
  task send_char(input [7:0] value);
    begin
      @(negedge clk_cpu);
      while (!char_ready) @(negedge clk_cpu);
      char_valid=1;char_data=value;
      @(negedge clk_cpu);
      char_valid=0;
      repeat(14) @(negedge clk_pixel);
    end
  endtask
  task write_gfx(input [5:0] index, input [23:0] value);
    begin
      @(negedge clk_pixel); gfx_valid=1;gfx_index=index;gfx_value=value;
      @(negedge clk_pixel); gfx_valid=0;
      repeat(3) @(negedge clk_pixel);
    end
  endtask
  initial begin
    repeat(6) @(negedge clk_pixel);
    resetn_cpu=1; resetn_pixel=1;
    repeat(10245) @(negedge clk_pixel);
    if (dut.clearing !== 1'b0) $fatal(1,"VRAM full clear did not finish");
    send_char("A");
    if (dut.text_mem[0] !== 8'h41) $fatal(1,"Text VRAM did not capture A");
    send_char(8'h0f); // GFX
    if (dut.terminal_mode !== 1'b0) $fatal(1,"GFX mode switch failed");
    write_gfx(6'd0,24'd100);  // x
    write_gfx(6'd1,24'd100);  // y
    write_gfx(6'd2,24'd100);  // width
    write_gfx(6'd3,24'd100);  // height
    write_gfx(6'd4,24'h00aaff); // BGR color
    write_gfx(6'd5,24'd1);  // enable
    write_gfx(6'd15,24'd1); // commit
    @(negedge clk_pixel); de=1;px=0;py=0;
    @(negedge clk_pixel);px=120;py=120;
    repeat(4) @(negedge clk_pixel);
    if (bgr_out !== 24'h00aaff)
       $fatal(1,"Sprite color failed, got=%h",bgr_out);
    leds=6'b000001;
    @(negedge clk_pixel);px=865;py=25;
    repeat(4) @(negedge clk_pixel);
    if (bgr_out !== 24'h30e030)
       $fatal(1,"LED HUD failed, got=%h",bgr_out);
    $display("PIKOSOL20K_RENDERER_SIM_PASS: VRAM GFX 8 slots LED HUD");
    $finish;
  end
endmodule
