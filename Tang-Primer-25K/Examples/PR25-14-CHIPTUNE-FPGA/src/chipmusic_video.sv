// PR25-14 original FPGA video + music generator on the verified HDMI stack.
// NTSC CEA mode 2: 720x480 active, 912x524 total at ~28.64 MHz.
module chipmusic_video (
  input logic clk,
  input logic clk_pixel_x5,
  input logic pll_lock,
  output logic tmds_clk_n,
  output logic tmds_clk_p,
  output logic [2:0] tmds_d_n,
  output logic [2:0] tmds_d_p
);
  // Preserve the same audio clock divider as original working video.v.
  // Pixel clock nominal 28.636 MHz; stream flagged 48 kHz to HDMI sink.
  logic clk_audio = 1'b0;
  logic [8:0] aclk_cnt = '0;
  always_ff @(posedge clk) begin
    if (!pll_lock) begin
      clk_audio <= 1'b0;
      aclk_cnt <= '0;
    end else if (aclk_cnt < (28542800 / 48000 / 2 - 1)) begin
      aclk_cnt <= aclk_cnt + 9'd1;
    end else begin
      aclk_cnt <= 9'd0;
      clk_audio <= ~clk_audio;
    end
  end

  logic [15:0] audio_l;
  logic [15:0] audio_r;
  logic beat_toggle;
  chipmusic_audio music (
    .clk_audio(clk_audio),
    .reset(~pll_lock),
    .audio_l(audio_l),
    .audio_r(audio_r),
    .beat_toggle(beat_toggle)
  );

  // Derived x/y refer to the pixel that will be consumed by HDMI
  // on the next posedge, allowing a synchronous BSRAM ROM read.
  logic [10:0] next_pixel_x;
  logic [9:0] next_pixel_y;
  logic [23:0] rgb;
  chipmusic_scene scene (
    .clk(clk),
    .next_x(next_pixel_x),
    .next_y(next_pixel_y),
    .beat_toggle(beat_toggle),
    .rgb(rgb)
  );

  logic [2:0] tmds;
  logic tmds_clock;
  hdmi #(
     .AUDIO_RATE(48000),
     .AUDIO_BIT_WIDTH(16),
     .VENDOR_NAME({"PiKoSoL",8'd0}),
     .PRODUCT_DESCRIPTION({"CHIPMUSIC",56'd0})
  ) hdmi (
     .clk_pixel_x5(clk_pixel_x5),
     .clk_pixel(clk),
     .clk_audio(clk_audio),
     .audio_sample_word({audio_l, audio_r}),
     .total_lines(9'd262),
     .reset(~pll_lock),
     .stmode(2'd0),
     .screen(2'd0),
     .rgb(rgb),
     .next_pixel_x(next_pixel_x),
     .next_pixel_y(next_pixel_y),
     .tmds(tmds),
     .tmds_clock(tmds_clock)
  );

  ELVDS_OBUF tmds_bufds [3:0] (
    .I({tmds_clock, tmds}),
    .O({tmds_clk_p, tmds_d_p}),
    .OB({tmds_clk_n, tmds_d_n})
  );
endmodule
