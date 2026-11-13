`timescale 1ns/1ps
// Four-cycle video pipeline integration requires a further top-level raster
// test. This test checks the renderer's three stages alone, plus frame commit.
module tb_renderer;
  reg clk_pixel=0, clk_cpu=0, resetn_pixel=0, resetn_cpu=0;
  always #5 clk_pixel=~clk_pixel;
  always #18 clk_cpu=~clk_cpu;
  reg de=0, frame_start=0;
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
    .de(de),.px(px),.py(py),.frame_start(frame_start),
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
  task commit_frame;
    begin
      @(negedge clk_pixel); frame_start=1; de=0;
      @(negedge clk_pixel); frame_start=0;
      repeat(4) @(negedge clk_pixel);
    end
  endtask
  task sample_pixel(input [10:0] x, input [9:0] y, input [23:0] expected);
    begin
      @(negedge clk_pixel); de=1; px=x; py=y;
      repeat(5) @(negedge clk_pixel);
      if (bgr_out !== expected)
        $fatal(1,"PIXEL_FAIL (%0d,%0d) got=%h expected=%h",x,y,bgr_out,expected);
    end
  endtask
  initial begin
    repeat(6) @(negedge clk_pixel);
    resetn_cpu=1; resetn_pixel=1;
    repeat(10245) @(negedge clk_pixel);
    if (dut.clearing !== 1'b0) $fatal(1,"VRAM full clear did not finish");
    send_char("A");
    if (dut.text_mem[0] !== 8'h41) $fatal(1,"Text VRAM did not capture A");
    send_char(8'h0f);
    if (dut.terminal_mode !== 1'b0) $fatal(1,"GFX mode switch failed");
    write_gfx(6'd0,24'd100);
    write_gfx(6'd1,24'd100);
    write_gfx(6'd2,24'd100);
    write_gfx(6'd3,24'd100);
    write_gfx(6'd4,24'h00aaff);
    write_gfx(6'd5,24'd1);
    write_gfx(6'd15,24'd1);
    commit_frame();
    sample_pixel(11'd120,10'd120,24'h00aaff);
    sample_pixel(11'd200,10'd120,24'h302018);
    sample_pixel(11'd120,10'd200,24'h302018);
    // 8th descriptor must be independent of A/B.
    write_gfx(6'd56,24'd110);
    write_gfx(6'd57,24'd110);
    write_gfx(6'd58,24'd50);
    write_gfx(6'd59,24'd50);
    write_gfx(6'd60,24'hcc7711);
    write_gfx(6'd61,24'd1);
    write_gfx(6'd63,24'd1);
    if (dut.color_live[7] !== 24'h0)
      $fatal(1,"Object 7 published before COMMIT");
    commit_frame();
    sample_pixel(11'd120,10'd120,24'hcc7711);
    sample_pixel(11'd105,10'd105,24'h00aaff);
    leds=6'b000001;
    sample_pixel(11'd865,10'd25,24'h30e030);
    sample_pixel(11'd930,10'd25,24'h505050);
    sample_pixel(11'd1279,10'd500,24'h302018);
    $display("PIKOSOL20K_RENDERER_PIPELINE_SIM_PASS");
    $finish;
  end
endmodule
