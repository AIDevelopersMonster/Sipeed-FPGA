// PR25 HDMI Audio BRAM 01 - self-contained picture + stereo test signal.
// No DDR/SDRAM, SPI, BL616, USB Host, ROM, or firmware.
// The only goal of this module is to generate colour bars and two low-volume
// audible square waves (approximately 500 Hz LEFT, 750 Hz RIGHT).
// Copyright (c) 2026 - MIT License (see LICENSE).
module pr25_av_content (
    input  logic        clk_audio,
    input  logic        reset,
    input  logic [10:0] cx,
    input  logic [9:0]  cy,
    output logic [23:0] rgb,
    output logic [15:0] audio_sample_word [1:0]
);
    logic [6:0] phase_left  = 7'd0; // modulo 96
    logic [5:0] phase_right = 6'd0; // modulo 64

    always_ff @(posedge clk_audio) begin
        if (reset) begin
            phase_left  <= 7'd0;
            phase_right <= 6'd0;
        end else begin
            phase_left <= phase_left == 7'd95 ? 7'd0 : phase_left + 7'd1;
            phase_right <= phase_right + 6'd1;
        end
    end

    // Signed 16-bit two's complement PCM: +/-2048 (~6.25% full scale).
    // The two channels have different periods to make channel separation audible.
    assign audio_sample_word[0] = phase_left  < 7'd48 ? 16'h0800 : 16'hF800;
    assign audio_sample_word[1] = phase_right < 6'd32 ? 16'h0800 : 16'hF800;

    always_comb begin
        rgb = 24'h000000;
        if (cx < 11'd1280 && cy < 10'd720) begin
            if      (cx < 11'd320) rgb = 24'hFF0000; // RED
            else if (cx < 11'd640) rgb = 24'h00FF00; // GREEN
            else if (cx < 11'd960) rgb = 24'h0000FF; // BLUE
            else                   rgb = 24'hFFFFFF; // WHITE

            // Black horizontal line to make monitor image easier to recognize.
            if (cy >= 10'd704 && cy < 10'd710)
                rgb = 24'h000000;
        end
    end
endmodule
