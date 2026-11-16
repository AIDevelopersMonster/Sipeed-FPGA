// PR25-HDMI-AUDIO-BRAM-01 experimental TOP for Tang Primer 25K + Dock.
// GW5A-LV25MG121NC1/I0, 50 MHz clock on E2, DVI PMOD in the SAME
// socket that gave A2600Nano Golden HDMI+audio BOARD PASS.
// HDMI audio source is original thisiseth/hdl-util IP fetched at pinned SHA.
// Program only SRAM; unverified until tested on physical board.
// Copyright (c) 2026 - MIT License (see LICENSE).
module pr25_hdmi_audio_top (
    input  wire       clk_50m,
    // Gowin IO_TYPE=LVCMOS33D automatically occupies differential pin pairs.
    // Output names deliberately match the working A2600Nano CST scheme.
    output wire       tmds_clk_p,
    output wire [2:0] tmds_d_p
);
    wire pll_lock;
    wire clk_pixel;
    wire clk_pixel_x5;

    // Exact vendor PLL used by thisiseth for his 720p HDMI project.
    // The generated PLL sets 75 MHz + 375 MHz, not exact 74.25/371.25 MHz.
    gowin_pll_hdmi_720 pll_hdmi (
        .clkin   (clk_50m),
        .clkout0 (clk_pixel),
        .clkout1 (clk_pixel_x5),
        .lock    (pll_lock)
    );

    logic [7:0] startup_count = 8'd0;
    always_ff @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock)
            startup_count <= 8'd0;
        else if (startup_count != 8'hFF)
            startup_count <= startup_count + 8'd1;
    end
    wire reset = (startup_count != 8'hFF);

    // Exact divider architecture used by thisiseth.
    // 75,000,000 / 1562 = about 48,015.36 samples/sec.
    // This is a first hardware smoke test, not a bit-perfect 48.000 kHz clock.
    localparam integer PIXEL_TO_AUDIO_DIV = 1562;
    logic [10:0] audio_div_count = 11'd0;
    logic clk_audio = 1'b0;

    always_ff @(posedge clk_pixel or negedge pll_lock) begin
        if (!pll_lock) begin
            audio_div_count <= 11'd0;
            clk_audio <= 1'b0;
        end else if (reset) begin
            audio_div_count <= 11'd0;
            clk_audio <= 1'b0;
        end else begin
            audio_div_count <= audio_div_count == (PIXEL_TO_AUDIO_DIV-1)
                             ? 11'd0 : audio_div_count + 11'd1;
            clk_audio <= audio_div_count >= (PIXEL_TO_AUDIO_DIV / 2);
        end
    end

    wire [23:0] rgb;
    wire [10:0] cx;
    wire [9:0] cy;
    wire [15:0] audio_sample_word [1:0];

    pr25_av_content content (
        .clk_audio         (clk_audio),
        .reset             (reset),
        .cx                (cx),
        .cy                (cy),
        .rgb               (rgb),
        .audio_sample_word (audio_sample_word)
    );

    // Original hdl-util/hdmi core bundled by thisiseth.
    // serializer.sv is selected through the GW_IDE branch, using Gowin OSER10.
    hdmi #(
        .VIDEO_ID_CODE      (4),       // 1280 x 720 active area
        .DVI_OUTPUT         (1'b0),    // MUST be HDMI, not video-only DVI
        .VIDEO_REFRESH_RATE (60.0),
        .AUDIO_RATE         (48000),
        .AUDIO_BIT_WIDTH    (16),
        .BIT_WIDTH          (11),
        .BIT_HEIGHT         (10)
    ) u_hdmi (
        .clk_pixel_x5      (clk_pixel_x5),
        .clk_pixel         (clk_pixel),
        .clk_audio         (clk_audio),
        .reset             (reset),
        .rgb               (rgb),
        .audio_sample_word (audio_sample_word),
        .tmds              (tmds_d_p),
        .tmds_clock        (tmds_clk_p),
        .cx                (cx),
        .cy                (cy),
        .frame_width       (),
        .frame_height      (),
        .screen_width      (),
        .screen_height     ()
    );
endmodule
