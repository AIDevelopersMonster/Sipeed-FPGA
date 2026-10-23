// LAB-04.2. PicoRV32 mini computer: built-in UART keyboard, six LEDs and HDMI.
// Input UART is shared with the CPU and passively tapped for HDMI text;
// outgoing UART from the CPU is also tapped, without changing its protocol.
// SPDX-License-Identifier: MIT
module lab04_cpu_hdmi_top (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,
    output wire uart_tx,
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
    wire [5:0] led_mask_sys;
    wire [5:0] led_mask_pixel;
    wire video_wr_valid, video_wr_ready;
    wire [3:0] video_wr_index;
    wire [23:0] video_wr_value;
    wire video_pixel_valid;
    wire [3:0] video_pixel_index;
    wire [23:0] video_pixel_value;
    lab04_cpu_soc u_soc (
        .clk(clk), .reset_n(video_resetn),
        .uart_rx(uart_rx), .uart_tx(uart_tx), .led_n(led_n),
         .led_mask_sys(led_mask_sys),
        .video_wr_valid(video_wr_valid), .video_wr_ready(video_wr_ready),
        .video_wr_index(video_wr_index), .video_wr_value(video_wr_value)
    );
    lab04_led_mask_cdc u_led_cdc (
        .clk_sys(clk), .resetn_sys(video_resetn),
        .mask_sys(led_mask_sys),
        .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
        .mask_pixel(led_mask_pixel)
    );
    lab04_video_cmd_cdc u_video_cdc (
        .clk_sys(clk), .resetn_sys(video_resetn),
        .wr_valid(video_wr_valid), .wr_ready(video_wr_ready),
        .wr_index(video_wr_index), .wr_value(video_wr_value),
        .clk_pixel(clk_pixel), .resetn_pixel(pixel_resetn),
        .event_valid(video_pixel_valid), .event_index(video_pixel_index),
        .event_value(video_pixel_value)
    );
    wire video_byte_valid, video_byte_ready;
    wire [7:0] video_byte;
    wire host_tap_overflow, cpu_tap_overflow;
    lab04_uart_tty_bridge #(.CLOCK_HZ(27000000), .BAUD(115200), .HOST_TAP_ENABLE(0)) u_tty (
        .clk(clk), .reset_n(video_resetn),
        .serial_from_pc(uart_rx), .serial_from_cpu(uart_tx),
        .char_valid(video_byte_valid), .char_ready(video_byte_ready),
        .char_data(video_byte),
        .host_overflow(host_tap_overflow), .cpu_overflow(cpu_tap_overflow)
    );
    lab04_svo_hdmi_top #(.LED_OSD_ENABLE(1), .GFX_ENABLE(1), .UI_SHELL_ENABLE(1), .CONSOLE_ENABLE(1)) u_hdmi (
        .clk(clk), .resetn(video_resetn),
        .pixel_resetn(pixel_resetn), .serdes_resetn(serdes_resetn),
        .clk_pixel(clk_pixel), .clk_5x_pixel(clk_5x_pixel),
        .term_in_tvalid(video_byte_valid),
        .term_in_tready(video_byte_ready),
        .term_in_tdata(video_byte),
         .led_mask_pixel(led_mask_pixel),
        .gfx_event_valid(video_pixel_valid),
        .gfx_event_index(video_pixel_index),
        .gfx_event_value(video_pixel_value),
        .tmds_clk_p(tmds_clk_p), .tmds_clk_n(tmds_clk_n),
        .tmds_d_p(tmds_d_p), .tmds_d_n(tmds_d_n)
    );
    // Overflow is visible in netlists, but not falsely reported to the CPU.
    // Reaching this condition would require a later explicit diagnostic interface.
    wire _unused = host_tap_overflow ^ cpu_tap_overflow;
endmodule
