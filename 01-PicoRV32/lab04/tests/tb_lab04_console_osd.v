`timescale 1ns/1ps
module tb_lab04_console_osd;
  reg clk_sys=0,clk_pixel=0;
  always #18.5 clk_sys=~clk_sys;
  always #20 clk_pixel=~clk_pixel;
  reg resetn_sys=0,resetn_pixel=0;
  reg char_valid=0;
  reg [7:0] char_data=0;
  wire char_ready;
  reg [5:0] led=0;
  reg gfx_event_valid=0;
  reg [3:0] gfx_event_index=0;
  reg [23:0] gfx_event_value=0;
  reg s_valid=0,s_user=0;
  reg [23:0] s_data=24'h012345;
  reg m_ready=1;
  wire s_ready,m_valid,m_user;
  wire [23:0] m_data;
  integer pixels=0;
  lab04_console_osd dut (
    .clk_sys(clk_sys),.resetn_sys(resetn_sys),
    .clk_pixel(clk_pixel),.resetn_pixel(resetn_pixel),
    .char_valid(char_valid),.char_ready(char_ready),.char_data(char_data),
    .led_mask_pixel(led),.gfx_event_valid(gfx_event_valid),
    .gfx_event_index(gfx_event_index),.gfx_event_value(gfx_event_value),
    .s_axis_tvalid(s_valid),.s_axis_tready(s_ready),
    .s_axis_tdata(s_data),.s_axis_tuser(s_user),
    .m_axis_tvalid(m_valid),.m_axis_tready(m_ready),
    .m_axis_tdata(m_data),.m_axis_tuser(m_user)
  );
  task send;
    input [7:0] value;
    begin
      @(negedge clk_sys);
      while (!char_ready) @(negedge clk_sys);
      char_data=value;char_valid=1;
      @(negedge clk_sys);char_valid=0;
      repeat(12) @(posedge clk_pixel);
    end
  endtask
  initial begin
    #100;resetn_pixel=1;resetn_sys=1;
    repeat(2600) @(posedge clk_pixel);
    if(dut.clearing!==0) $fatal(1,"VRAM initial clear not finished");
    if(dut.static_char(5'd1,7'd2)!==8'h50)
      $fatal(1,"PiKoSoL title ROM missing");
    if(dut.font_mem[11'h501] !== 8'h78)
      $fatal(1,"font BSRAM initial file missing or scanline reversed");
    send(8'h41);send(8'h42);send(8'h43);
    repeat(15) @(posedge clk_pixel);
    if(dut.log_mem[2356]!==8'h41 || dut.log_mem[2357]!==8'h42 ||
       dut.log_mem[2358]!==8'h43) $fatal(1,"terminal bytes lost");
    send(8'h0a);
    repeat(95) @(posedge clk_pixel);
    if(dut.wr_row!==5'd0 || dut.wr_col!==0 || dut.clearing!==0)
      $fatal(1,"line advance or clear failed");
    send(8'h58);send(8'h59);
    repeat(15) @(posedge clk_pixel);
    if(dut.log_mem[0]!==8'h58 || dut.log_mem[1]!==8'h59)
      $fatal(1,"next terminal row failed");
    // No additional CDC: CPU mode selection travels as ordinary UART bytes.
    send(8'h0f);
    if (dut.shell_term!==0) $fatal(1,"GFX mode command ignored");
    send(8'h0e);
    if (dut.shell_term!==1) $fatal(1,"TERM mode command ignored");
    // Verify 32-line line-buffer capacity and physical ring indexing.
    if (dut.row_base(5'd31)!==12'd2356)
      $fatal(1,"32-row ring address mapping failed");
    // Pixels at 640 wide, a single SOF and two-stage video pipeline.
    @(negedge clk_pixel);s_valid=1;s_user=1;
    @(negedge clk_pixel);s_user=0;
    repeat(8000) begin
      @(negedge clk_pixel);
      if(s_ready) pixels=pixels+1;
    end
    if(dut.ypos<9'd12) $fatal(1,"raster did not advance");
    if(!m_valid) $fatal(1,"video pipeline not valid");
    // Output data and SOF must be stable for arbitrary downstream stalls.
    @(negedge clk_pixel); m_ready=0;
    repeat(4) @(posedge clk_pixel);
    begin : check_stall
      reg [23:0] captured;
      reg captured_user;
      captured=m_data;
      captured_user=m_user;
      repeat(10) begin
        @(negedge clk_pixel);
        if (m_valid !== 1'b1 || m_data !== captured || m_user !== captured_user)
          $fatal(1,"console pixel pipeline changed while stalled");
      end
    end
    @(negedge clk_pixel); m_ready=1;
    // 40 * 12 text rows: text_row must not wrap at 32 (y=384).
    // Input rest of frame, no extra start-of-frame pulse.
    repeat(240000) @(posedge clk_pixel);
    if(dut.ypos < 9'd384 || dut.text_row < 6'd32)
      $fatal(1,"text row counter wrapped before y=480");
    $display("LAB0432_CONSOLE_RTL_PASS: TERM/GFX mode, 32x76 terminal VRAM, LF, pixel pipeline");
    $finish;
  end
  initial begin #13000000;$fatal(1,"console simulation timeout");end
endmodule
