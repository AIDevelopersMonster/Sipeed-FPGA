// KonSol RS-003 BREAKOUT RGB for Tang Nano 9K: Web Serial UART -> Breakout -> HDMI.
// Uses the same SVO clock/video building blocks as hardware-tested LAB-04.
// Newly authored glue; Gowin and SVO IP are supplied by the existing LAB-04
// pinned local dependency, not copied to this directory.
// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
`include "svo_defines.vh"
module breakout_uart_hdmi_top (
    input  wire       clk,       // Tang Nano 9K 27 MHz, pin 52
    input  wire       reset_n,   // onboard S1, active low, pin 3
    input  wire       uart_rx,   // FT2232 channel B -> FPGA pin 18
    output wire [5:0] led_n,     // palette 1-of-4 + AI status, active low
    output wire       tmds_clk_p,
    output wire       tmds_clk_n,
    output wire [2:0] tmds_d_p,
    output wire [2:0] tmds_d_n
);
    parameter SVO_MODE           = "640x480V";
    parameter SVO_FRAMERATE      = 60;
    parameter SVO_BITS_PER_PIXEL = 24;
    parameter SVO_BITS_PER_RED   = 8;
    parameter SVO_BITS_PER_GREEN = 8;
    parameter SVO_BITS_PER_BLUE  = 8;
    parameter SVO_BITS_PER_ALPHA = 0;

    wire clk_pixel, clk_5x_pixel;
    wire resetn_sys, resetn_pixel, resetn_serdes, pll_locked;
    lab04_video_clocks u_clocks (
        .clk27(clk), .reset_n(reset_n),
        .clk_pixel(clk_pixel), .clk_5x_pixel(clk_5x_pixel),
        .video_resetn(resetn_sys), .pixel_resetn(resetn_pixel),
        .serdes_resetn(resetn_serdes), .pll_locked(pll_locked)
    );

    // The existing UART RX core includes a two-flop asynchronous RX synchronizer.
    // Run it at the pixel clock: game logic and HDMI pixels stay in ONE domain.
    wire [7:0] rx_byte;
    wire rx_valid, rx_framing_error;
    uart_rx_8n1 #(.CLOCK_HZ(25200000), .BAUD(115200)) u_uart (
        .clk(clk_pixel), .reset_n(resetn_pixel), .rx(uart_rx),
        .data(rx_byte), .valid(rx_valid), .framing_error(rx_framing_error)
    );

    wire src_valid, src_ready, game_valid, game_ready;
    wire [23:0] src_data, game_data;
    wire [0:0] src_user, game_user;
    wire [1:0] palette;
    wire ai_on;
    svo_tcard #(`SVO_PASS_PARAMS) u_tcard (
        .clk(clk_pixel), .resetn(resetn_pixel),
        .out_axis_tvalid(src_valid), .out_axis_tready(src_ready),
        .out_axis_tdata(src_data), .out_axis_tuser(src_user)
    );
    breakout_rgb_core u_breakout (
        .clk(clk_pixel), .reset_n(resetn_pixel),
        .rx_byte(rx_byte), .rx_valid(rx_valid),
        .palette(palette), .ai_on(ai_on),
        .s_axis_tvalid(src_valid), .s_axis_tready(src_ready),
        .s_axis_tdata(src_data), .s_axis_tuser(src_user),
        .m_axis_tvalid(game_valid), .m_axis_tready(game_ready),
        .m_axis_tdata(game_data), .m_axis_tuser(game_user)
    );

    // Four LEDs indicate the selected palette; LED 6 is on while AI is on.
    assign led_n = ~{ai_on, 1'b0, (4'b0001 << palette)};

    wire enc_valid, enc_ready;
    wire [23:0] enc_data;
    wire [3:0] enc_user;
    svo_enc #(`SVO_PASS_PARAMS) u_enc (
        .clk(clk_pixel), .resetn(resetn_pixel),
        .in_axis_tvalid(game_valid), .in_axis_tready(game_ready),
        .in_axis_tdata(game_data), .in_axis_tuser(game_user),
        .out_axis_tvalid(enc_valid), .out_axis_tready(enc_ready),
        .out_axis_tdata(enc_data), .out_axis_tuser(enc_user)
    );
    assign enc_ready = 1'b1;

    wire [2:0] tmds_data;
    wire [2:0] d0,d1,d2,d3,d4,d5,d6,d7,d8,d9;
    // In SVO, BGR888 is carried as B:[23:16], G:[15:8], R:[7:0].
    svo_tmds u_blue (
        .clk(clk_pixel), .resetn(resetn_pixel),
        .de(!enc_user[3]), .ctrl(enc_user[2:1]),
        .din(enc_data[23:16]),
        .dout({d9[0],d8[0],d7[0],d6[0],d5[0],d4[0],d3[0],d2[0],d1[0],d0[0]})
    );
    svo_tmds u_green (
        .clk(clk_pixel), .resetn(resetn_pixel),
        .de(!enc_user[3]), .ctrl(2'b00),
        .din(enc_data[15:8]),
        .dout({d9[1],d8[1],d7[1],d6[1],d5[1],d4[1],d3[1],d2[1],d1[1],d0[1]})
    );
    svo_tmds u_red (
        .clk(clk_pixel), .resetn(resetn_pixel),
        .de(!enc_user[3]), .ctrl(2'b00),
        .din(enc_data[7:0]),
        .dout({d9[2],d8[2],d7[2],d6[2],d5[2],d4[2],d3[2],d2[2],d1[2],d0[2]})
    );

    // Reuse LAB-04's per-lane synchronized OSER10 reset release.
    wire [2:0] local_serdes_resetn;
    genvar lane;
    generate for(lane=0; lane<3; lane=lane+1) begin: g_reset
        reg lane_resetn /* synthesis syn_preserve = 1 */ = 1'b0;
        always @(posedge clk_5x_pixel or negedge resetn_serdes) begin
            if(!resetn_serdes) lane_resetn <= 1'b0;
            else lane_resetn <= 1'b1;
        end
        assign local_serdes_resetn[lane] = lane_resetn;
    end endgenerate
    OSER10 u_serializer [2:0] (
        .Q(tmds_data),
        .D0(d0), .D1(d1), .D2(d2), .D3(d3), .D4(d4),
        .D5(d5), .D6(d6), .D7(d7), .D8(d8), .D9(d9),
        .PCLK(clk_pixel), .FCLK(clk_5x_pixel),
        .RESET(~local_serdes_resetn)
    );
    ELVDS_OBUF u_hdmi [3:0] (
        .I({clk_pixel,tmds_data}),
        .O({tmds_clk_p,tmds_d_p}), .OB({tmds_clk_n,tmds_d_n})
    );
    wire _unused = pll_locked ^ resetn_sys ^ rx_framing_error ^ enc_valid;
endmodule
