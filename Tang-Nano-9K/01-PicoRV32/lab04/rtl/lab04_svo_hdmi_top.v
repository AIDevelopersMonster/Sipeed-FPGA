/*
 * LAB-04 HDMI adaptation of SVO / Simple Video Out FPGA Core.
 * Based on Sipeed PicoTiny svo_hdmi_top.v, revision:
 * https://github.com/sipeed/TangNano-9K-example/tree/c3b795799f23de91982be52db4273a8eea100cdb/picotiny
 *
 * Upstream copyright (C) 2014 Clifford Wolf <clifford@clifford.at>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * LAB-04 change: explicitly EXPORT the terminal INPUT's ready handshake.
 * Upstream svo_hdmi_top.v exposes term_out_tready (the PIXEL/OVERLAY output
 * ready), whereas its svo_term.in_axis_tready wire is implicit and UNEXPOSED.
 * Connecting a producer to upstream term_out_tready silently loses chars.
 * This adaptation corrects the interface without altering third-party files.
 */
`timescale 1ns/1ps
`include "svo_defines.vh"
module lab04_svo_hdmi_top #(parameter LED_OSD_ENABLE = 0, parameter GFX_ENABLE = 0, parameter UI_SHELL_ENABLE = 0, parameter CONSOLE_ENABLE = 0) (
    input wire clk,
    input wire resetn,         // clk (27 MHz) domain
    input wire pixel_resetn,   // clk_pixel (25.2 MHz) domain
    input wire serdes_resetn,  // clk_5x_pixel (126 MHz) domain
    input wire clk_pixel,
    input wire clk_5x_pixel,
    input wire term_in_tvalid,
    output wire term_in_tready,
    input wire [7:0] term_in_tdata,
    input wire [5:0] led_mask_pixel, // already transferred to pixel domain
    input wire gfx_event_valid,
    input wire [3:0] gfx_event_index,
    input wire [23:0] gfx_event_value,
    output wire tmds_clk_n,
    output wire tmds_clk_p,
    output wire [2:0] tmds_d_n,
    output wire [2:0] tmds_d_p
);
    parameter SVO_MODE = "640x480V";
    parameter SVO_FRAMERATE = 60;
    parameter SVO_BITS_PER_PIXEL = 24;
    parameter SVO_BITS_PER_RED = 8;
    parameter SVO_BITS_PER_GREEN = 8;
    parameter SVO_BITS_PER_BLUE = 8;
    parameter SVO_BITS_PER_ALPHA = 0;
    localparam [SVO_BITS_PER_PIXEL-1:0] white_pixval = ~0;

    wire vdma_tvalid, vdma_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] vdma_tdata;
    wire [0:0] vdma_tuser;
    wire term_out_tvalid, term_out_tready;
    wire [1:0] term_out_tdata;
    wire [0:0] term_out_tuser;
    wire video_tvalid, video_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] video_tdata;
    wire [0:0] video_tuser;
    wire video_enc_tvalid, video_enc_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] video_enc_tdata;
    wire [3:0] video_enc_tuser;
    wire [2:0] tmds_d;
    wire [2:0] tmds_d0, tmds_d1, tmds_d2, tmds_d3, tmds_d4;
    wire [2:0] tmds_d5, tmds_d6, tmds_d7, tmds_d8, tmds_d9;
    // Reset release is synchronized at the clock-generator boundary.
    // svo_term internally re-synchronizes the sys reset for its oclk domain.

    svo_tcard #(`SVO_PASS_PARAMS) u_tcard (
        .clk(clk_pixel), .resetn(pixel_resetn),
        .out_axis_tvalid(vdma_tvalid), .out_axis_tready(vdma_tready),
        .out_axis_tdata(vdma_tdata), .out_axis_tuser(vdma_tuser)
    );
    generate
        if (!CONSOLE_ENABLE) begin: g_legacy_term
        svo_term #(`SVO_PASS_PARAMS) u_term (
            .clk(clk), .oclk(clk_pixel), .resetn(resetn),
            .in_axis_tvalid(term_in_tvalid),
            .in_axis_tready(term_in_tready), // CORRECT input ready for ASCII stream
            .in_axis_tdata(term_in_tdata),
            .out_axis_tvalid(term_out_tvalid),
            .out_axis_tready(term_out_tready),
            .out_axis_tdata(term_out_tdata), .out_axis_tuser(term_out_tuser)
        );
        end else begin: g_no_legacy_term
            assign term_out_tvalid=1'b0;
            assign term_out_tdata=2'b0;
            assign term_out_tuser=1'b0;
        end
    endgenerate
    // Flat background is retained; console selection below changes only text rendering.
    wire ui_tvalid, ui_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] ui_tdata;
    wire [0:0] ui_tuser;
    generate
        if (UI_SHELL_ENABLE) begin: g_visual_shell
            lab04_ui_background u_background (
                .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
                .s_axis_tvalid(vdma_tvalid), .s_axis_tready(vdma_tready),
                .s_axis_tdata(vdma_tdata), .s_axis_tuser(vdma_tuser),
                .m_axis_tvalid(ui_tvalid), .m_axis_tready(ui_tready),
                .m_axis_tdata(ui_tdata), .m_axis_tuser(ui_tuser)
            );
        end else begin: g_no_visual_shell
            assign ui_tvalid=vdma_tvalid;
            assign vdma_tready=ui_tready;
            assign ui_tdata=vdma_tdata;
            assign ui_tuser=vdma_tuser;
        end
    endgenerate
    // Graphics underlays either the legacy SVO overlay or the new addressable text renderer.
    wire gfx_tvalid, gfx_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] gfx_tdata;
    wire [0:0] gfx_tuser;
    generate
        if (GFX_ENABLE) begin: g_cpu_graphics
            lab04_graphics_osd u_graphics (
                .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
                .event_valid(gfx_event_valid),
                .event_index(gfx_event_index), .event_value(gfx_event_value),
                .s_axis_tvalid(ui_tvalid), .s_axis_tready(ui_tready),
                .s_axis_tdata(ui_tdata), .s_axis_tuser(ui_tuser),
                .m_axis_tvalid(gfx_tvalid), .m_axis_tready(gfx_tready),
                .m_axis_tdata(gfx_tdata), .m_axis_tuser(gfx_tuser)
            );
        end else begin: g_no_graphics
            assign gfx_tvalid = ui_tvalid;
            assign ui_tready = gfx_tready;
            assign gfx_tdata = ui_tdata;
            assign gfx_tuser = ui_tuser;
        end
    endgenerate

    wire mixed_tvalid, mixed_tready;
    wire [SVO_BITS_PER_PIXEL-1:0] mixed_tdata;
    wire [0:0] mixed_tuser;
    generate
        if (CONSOLE_ENABLE) begin: g_addressable_console
            lab04_console_osd u_console (
                .clk_sys(clk), .resetn_sys(resetn),
                .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
                .char_valid(term_in_tvalid), .char_ready(term_in_tready),
                .char_data(term_in_tdata),
                .led_mask_pixel(led_mask_pixel),
                .gfx_event_valid(gfx_event_valid),
                .gfx_event_index(gfx_event_index),
                .gfx_event_value(gfx_event_value),
                .s_axis_tvalid(gfx_tvalid), .s_axis_tready(gfx_tready),
                .s_axis_tdata(gfx_tdata), .s_axis_tuser(gfx_tuser),
                .m_axis_tvalid(mixed_tvalid), .m_axis_tready(mixed_tready),
                .m_axis_tdata(mixed_tdata), .m_axis_tuser(mixed_tuser)
            );
        end else begin: g_legacy_overlay
        svo_overlay #(`SVO_PASS_PARAMS) u_overlay (
            .clk(clk_pixel), .resetn(pixel_resetn), .enable(1'b1),
            .in_axis_tvalid(gfx_tvalid), .in_axis_tready(gfx_tready),
            .in_axis_tdata(gfx_tdata), .in_axis_tuser(gfx_tuser),
            .over_axis_tvalid(term_out_tvalid),
            .over_axis_tready(term_out_tready),
            .over_axis_tdata(white_pixval),
            .over_axis_tuser({term_out_tdata == 2'b10, term_out_tuser}),
            .out_axis_tvalid(mixed_tvalid), .out_axis_tready(mixed_tready),
            .out_axis_tdata(mixed_tdata), .out_axis_tuser(mixed_tuser)
        );
        end
    endgenerate
    generate
        if (LED_OSD_ENABLE) begin: g_led_osd
            // The existing six-cell HUD is FOREGROUND, above text and sprites.
            lab04_led_osd u_led_osd (
                .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
                .mask_pixel(led_mask_pixel),
                .s_axis_tvalid(mixed_tvalid), .s_axis_tready(mixed_tready),
                .s_axis_tdata(mixed_tdata), .s_axis_tuser(mixed_tuser),
                .m_axis_tvalid(video_tvalid), .m_axis_tready(video_tready),
                .m_axis_tdata(video_tdata), .m_axis_tuser(video_tuser)
            );
        end else begin: g_no_led_osd
            assign video_tvalid = mixed_tvalid;
            assign mixed_tready = video_tready;
            assign video_tdata = mixed_tdata;
            assign video_tuser = mixed_tuser;
        end
    endgenerate
    svo_enc #(`SVO_PASS_PARAMS) u_enc (
        .clk(clk_pixel), .resetn(pixel_resetn),
        .in_axis_tvalid(video_tvalid), .in_axis_tready(video_tready),
        .in_axis_tdata(video_tdata), .in_axis_tuser(video_tuser),
        .out_axis_tvalid(video_enc_tvalid), .out_axis_tready(video_enc_tready),
        .out_axis_tdata(video_enc_tdata), .out_axis_tuser(video_enc_tuser)
    );
    assign video_enc_tready = 1'b1;

    svo_tmds u_tmds0 (
        .clk(clk_pixel), .resetn(pixel_resetn),
        .de(!video_enc_tuser[3]), .ctrl(video_enc_tuser[2:1]),
        .din(video_enc_tdata[23:16]),
        .dout({tmds_d9[0],tmds_d8[0],tmds_d7[0],tmds_d6[0],tmds_d5[0],
               tmds_d4[0],tmds_d3[0],tmds_d2[0],tmds_d1[0],tmds_d0[0]})
    );
    svo_tmds u_tmds1 (
        .clk(clk_pixel), .resetn(pixel_resetn),
        .de(!video_enc_tuser[3]), .ctrl(2'b0),
        .din(video_enc_tdata[15:8]),
        .dout({tmds_d9[1],tmds_d8[1],tmds_d7[1],tmds_d6[1],tmds_d5[1],
               tmds_d4[1],tmds_d3[1],tmds_d2[1],tmds_d1[1],tmds_d0[1]})
    );
    svo_tmds u_tmds2 (
        .clk(clk_pixel), .resetn(pixel_resetn),
        .de(!video_enc_tuser[3]), .ctrl(2'b0),
        .din(video_enc_tdata[7:0]),
        .dout({tmds_d9[2],tmds_d8[2],tmds_d7[2],tmds_d6[2],tmds_d5[2],
               tmds_d4[2],tmds_d3[2],tmds_d2[2],tmds_d1[2],tmds_d0[2]})
    );
    // Local reset release for each OSER10. The upstream serdes_resetn is
    // already synchronized to the 126 MHz domain and asserts asynchronously.
    // Its fanout now drives three nearby FFs, each driving ONE physical OSER10.
    // syn_preserve prevents synthesis from merging identical reset registers.
    // This changes routing topology, not clock frequency or reset polarity.
    wire [2:0] serdes_local_resetn;
    genvar lane;
    generate
        for (lane=0; lane<3; lane=lane+1) begin: g_serdes_reset_lane
            reg lane_resetn /* synthesis syn_preserve = 1 */ = 1'b0;
            always @(posedge clk_5x_pixel or negedge serdes_resetn) begin
                if (!serdes_resetn) lane_resetn <= 1'b0;
                else lane_resetn <= 1'b1;
            end
            assign serdes_local_resetn[lane] = lane_resetn;
        end
    endgenerate

    OSER10 u_tmds_serializer [2:0] (
        .Q(tmds_d),
        .D0(tmds_d0), .D1(tmds_d1), .D2(tmds_d2), .D3(tmds_d3),
        .D4(tmds_d4), .D5(tmds_d5), .D6(tmds_d6), .D7(tmds_d7),
        .D8(tmds_d8), .D9(tmds_d9),
        .PCLK(clk_pixel), .FCLK(clk_5x_pixel), .RESET(~serdes_local_resetn)
    );
    ELVDS_OBUF u_tmds_lvds [3:0] (
        .I({clk_pixel,tmds_d}),
        .O({tmds_clk_p,tmds_d_p}),
        .OB({tmds_clk_n,tmds_d_n})
    );
endmodule
