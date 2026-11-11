// LAB-04.1 independent FPGA HDMI test; no CPU, no UART, no external pins.
// Shows SVO color bars / test card with a short banner and cycles 0..6 LEDs.
// Video uses the official Sipeed PicoTiny SimpleVOut modules fetched at a pinned revision.
// SPDX-License-Identifier: MIT
module lab04_hdmi_smoke_top (
    input wire clk,
    input wire reset_n,
    output wire [5:0] led_n,
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    wire clk_pixel, clk_5x_pixel, video_resetn, pixel_resetn, serdes_resetn, pll_locked;
    lab04_video_clocks u_clock (
        .clk27(clk), .reset_n(reset_n),
        .clk_pixel(clk_pixel), .clk_5x_pixel(clk_5x_pixel),
        .video_resetn(video_resetn), .pixel_resetn(pixel_resetn),
        .serdes_resetn(serdes_resetn), .pll_locked(pll_locked)
    );

    reg [24:0] tick;
    reg [2:0] led_count;
    always @(posedge clk or negedge video_resetn) begin
        if (!video_resetn) begin
            tick <= 0;
            led_count <= 0;
        end else if (tick == 25'd13499999) begin
            tick <= 0;
            led_count <= (led_count == 6) ? 0 : led_count + 1'b1;
        end else tick <= tick + 1'b1;
    end
    reg [5:0] mask;
    always @* begin
        case (led_count)
            0: mask = 6'h00;
            1: mask = 6'h01;
            2: mask = 6'h03;
            3: mask = 6'h07;
            4: mask = 6'h0f;
            5: mask = 6'h1f;
            default: mask = 6'h3f;
        endcase
    end
    assign led_n = ~mask;

    // SVO terminal accepts byte streams; valid/ready guards every character.
    reg [5:0] banner_index;
    wire banner_ready;
    wire banner_valid = banner_index < 6'd21;
    reg [7:0] banner_char;
    always @* begin
        case (banner_index)
             0: banner_char = "L";  1: banner_char = "A";
             2: banner_char = "B";  3: banner_char = "-";
             4: banner_char = "0";  5: banner_char = "4";
             6: banner_char = " ";  7: banner_char = "H";
             8: banner_char = "D";  9: banner_char = "M";
            10: banner_char = "I"; 11: banner_char = " ";
            12: banner_char = "T"; 13: banner_char = "E";
            14: banner_char = "S"; 15: banner_char = "T";
            16: banner_char = 8'h0a;
            17: banner_char = "S"; 18: banner_char = "V";
            19: banner_char = "O"; 20: banner_char = 8'h0a;
            default: banner_char = 8'h00;
        endcase
    end
    always @(posedge clk or negedge video_resetn) begin
        if (!video_resetn) banner_index <= 0;
        else if (banner_valid && banner_ready) banner_index <= banner_index + 1'b1;
    end

    lab04_svo_hdmi_top u_hdmi (
        .clk(clk), .resetn(video_resetn),
        .pixel_resetn(pixel_resetn), .serdes_resetn(serdes_resetn),
        .clk_pixel(clk_pixel), .clk_5x_pixel(clk_5x_pixel),
        .term_in_tvalid(banner_valid), .term_in_tready(banner_ready),
        .term_in_tdata(banner_char),
        .led_mask_pixel(6'b000000),
        .gfx_event_valid(1'b0), .gfx_event_index(4'd0), .gfx_event_value(24'd0), // Smoke mode does not display CPU OSD
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p), .tmds_d_n(tmds_d_n)
    );
endmodule
