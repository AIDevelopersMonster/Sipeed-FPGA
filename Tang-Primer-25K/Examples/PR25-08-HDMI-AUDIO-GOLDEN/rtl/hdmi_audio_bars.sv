// SPDX-License-Identifier: GPL-3.0-only
// PR25-08, 2026-11-14. Independent colorbars + audio test using unchanged
// A2600Nano v2.5 (GPL-3.0) HDMI packet encoder and GW5A-25A PLL.
module hdmi_audio_bars (
    input  wire       clk_pixel,
    input  wire       clk_pixel_x5,
    input  wire       pll_locked,
    input  wire       ext_reset,
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    // Allow the original PLL_INIT module to qualify LOCK before video.
    // S2/H11 synchronously resets video/audio, not the upstream PLL_INIT.
    reg [7:0] lock_delay = 8'd0;
    reg key_meta = 1'b0;
    reg key_sync = 1'b0;
    always @(posedge clk_pixel or negedge pll_locked) begin
        if (!pll_locked) begin
            lock_delay <= 8'd0;
            key_meta   <= 1'b0;
            key_sync   <= 1'b0;
        end else begin
            lock_delay <= {lock_delay[6:0], 1'b1};
            key_meta   <= ext_reset;
            key_sync   <= key_meta;
        end
    end
    wire rst = ~lock_delay[7] | key_sync;

    // Match A2600 hdmi.sv NTSC geometry: 912x524 total, 720x480 active.
    // Its internal cx/cy counters advance in lockstep with these counters.
    reg [10:0] x = 11'd0;
    reg [9:0]  y = 10'd0;
    always @(posedge clk_pixel) begin
        if (rst) begin
            x <= 11'd0;
            y <= 10'd0;
        end else if (x == 11'd911) begin
            x <= 11'd0;
            if (y == 10'd523) y <= 10'd0;
            else y <= y + 1'b1;
        end else begin
            x <= x + 1'b1;
        end
    end

    reg [23:0] rgb;
    always @* begin
        rgb = 24'h000000;
        if (x < 11'd720 && y < 10'd480) begin
            if (x < 11'd8 || x >= 11'd712 ||
                y < 10'd8 || y >= 10'd472 ||
                (y >= 10'd238 && y < 10'd242))
                rgb = 24'hFFFFFF; // white border and horizontal center
            else if (x < 11'd90)  rgb = 24'hFFFFFF;
            else if (x < 11'd180) rgb = 24'hFFFF00;
            else if (x < 11'd270) rgb = 24'h00FFFF;
            else if (x < 11'd360) rgb = 24'h00FF00;
            else if (x < 11'd450) rgb = 24'hFF00FF;
            else if (x < 11'd540) rgb = 24'hFF0000;
            else if (x < 11'd630) rgb = 24'h0000FF;
            else                  rgb = 24'h181818;
        end
    end

    // Exactly reproduce upstream A2600 video.v divider: it toggles
    // its sample clock every 297 pixels, giving about 48.2 kHz.
    // 48 successive samples form one gentle ~1 kHz square-wave period.
    reg [8:0] audio_div = 9'd0;
    reg clk_audio = 1'b0;
    reg [5:0] tone_step = 6'd0;
    always @(posedge clk_pixel) begin
        if (rst) begin
            audio_div <= 9'd0;
            clk_audio <= 1'b0;
            tone_step <= 6'd0;
        end else if (audio_div == 9'd296) begin
            audio_div <= 9'd0;
            clk_audio <= ~clk_audio;
            if (!clk_audio) begin
                if (tone_step == 6'd47) tone_step <= 6'd0;
                else tone_step <= tone_step + 1'b1;
            end
        end else begin
            audio_div <= audio_div + 1'b1;
        end
    end
    wire [15:0] sample = tone_step < 6'd24 ? 16'h1800 : 16'hE800;
    wire [15:0] samples [1:0];
    assign samples[0] = sample;
    assign samples[1] = sample;

    wire [2:0] tmds;
    wire tmds_clock;
    hdmi #(
        .AUDIO_RATE(48000),
        .AUDIO_BIT_WIDTH(16),
        .VENDOR_NAME({"AIDev",24'd0}),
        .PRODUCT_DESCRIPTION({"TP25 HDMI TEST",16'd0})
    ) hdmi_core (
        .clk_pixel_x5(clk_pixel_x5),
        .clk_pixel(clk_pixel),
        .clk_audio(clk_audio),
        .total_lines(9'd262),
        .reset(rst),
        .stmode(2'd0),
        .screen(2'd0),
        .rgb(rgb),
        .audio_sample_word(samples),
        .tmds(tmds),
        .tmds_clock(tmds_clock)
    );

    // Preserve all four proven differential line drivers.
    ELVDS_OBUF tmds_bufds [3:0] (
        .I ({tmds_clock, tmds}),
        .O ({tmds_clk_p, tmds_d_p}),
        .OB({tmds_clk_n, tmds_d_n})
    );
endmodule
