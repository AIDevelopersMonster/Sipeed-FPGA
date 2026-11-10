// PiKoSoL 20K / PicoRV32 / 720p native HDMI / six LED.
// Reuses proven Tang Nano 9K CPU/terminal command and 20K Gowin DVI PHY paths.
// Candidate RTL, NOT board verified. Only program FPGA SRAM after Gowin STA.
// SPDX-License-Identifier: MIT
module pikosol20k_top (
    input  wire clk27,          // Tang Nano 20K, FPGA pin 4
    input  wire reset_btn,      // active high button, pin 88
    input  wire uart_rx,        // pin 70
    output wire uart_tx,        // pin 69
    output wire [5:0] led_n,   // active low, pins 15..20
    output wire tmds_clk_p, output wire tmds_clk_n,
    output wire [2:0] tmds_d_p, output wire [2:0] tmds_d_n
);
    // Keep the CPU running on its validated 27 MHz crystal initially.
    // ROM/RAM/video descriptors are enlarged; future PLL clock is independent.
    reg [15:0] por_count = 16'hffff;
    reg [1:0] cpu_release = 2'b00;
    always @(posedge clk27 or posedge reset_btn) begin
        if (reset_btn) begin
            por_count <= 16'hffff;
            cpu_release <= 2'b00;
        end else begin
            if (por_count != 0) por_count <= por_count - 1'b1;
            cpu_release <= {cpu_release[0], (por_count == 0)};
        end
    end
    wire resetn_cpu = cpu_release[1];

    // Pin-compatible Sipeed 20K HDMI PHY, unchanged from EX20-05.16.
    wire serial_clk, pix_clk, pll_locked;
    TMDS_rPLL u_pll (.clkin(clk27), .clkout(serial_clk), .lock(pll_locked));
    wire pix_reset_request_n = pll_locked && resetn_cpu;
    CLKDIV u_clkdiv (
        .RESETN(pix_reset_request_n),
        .HCLKIN(serial_clk), .CLKOUT(pix_clk), .CALIB(1'b1)
    );
    defparam u_clkdiv.DIV_MODE = "5";
    defparam u_clkdiv.GSREN = "false";

    reg [1:0] pixel_release = 2'b00;
    always @(posedge pix_clk or negedge pix_reset_request_n) begin
        if (!pix_reset_request_n) pixel_release <= 2'b00;
        else pixel_release <= {pixel_release[0], 1'b1};
    end
    wire resetn_pixel = pixel_release[1];

    wire [5:0] led_mask_cpu, led_mask_pixel;
    wire wr_valid, wr_ready, pix_gfx_valid;
    wire [5:0] wr_index, pix_gfx_index;
    wire [23:0] wr_value, pix_gfx_value;
    pikosol20k_cpu_soc u_cpu (
        .clk(clk27), .reset_n(resetn_cpu),
        .uart_rx(uart_rx), .uart_tx(uart_tx),
        .led_n(led_n), .led_mask_sys(led_mask_cpu),
        .video_wr_valid(wr_valid), .video_wr_ready(wr_ready),
        .video_wr_index(wr_index), .video_wr_value(wr_value)
    );
    lab04_led_mask_cdc u_led_cdc (
        .clk_sys(clk27), .resetn_sys(resetn_cpu),
        .mask_sys(led_mask_cpu),
        .clk_pixel(pix_clk), .resetn_pixel(resetn_pixel),
        .mask_pixel(led_mask_pixel)
    );
    pikosol20k_video_cmd_cdc u_graphics_cdc (
        .clk_sys(clk27), .resetn_sys(resetn_cpu),
        .wr_valid(wr_valid), .wr_ready(wr_ready),
        .wr_index(wr_index), .wr_value(wr_value),
        .clk_pixel(pix_clk), .resetn_pixel(resetn_pixel),
        .event_valid(pix_gfx_valid), .event_index(pix_gfx_index),
        .event_value(pix_gfx_value)
    );
    wire tty_valid, tty_ready;
    wire [7:0] tty_byte;
    wire host_overflow, cpu_overflow;
    lab04_uart_tty_bridge #(
        .CLOCK_HZ(27000000), .BAUD(115200), .HOST_TAP_ENABLE(0)
    ) u_uart_tap (
        .clk(clk27), .reset_n(resetn_cpu),
        .serial_from_pc(uart_rx), .serial_from_cpu(uart_tx),
        .char_valid(tty_valid), .char_ready(tty_ready),
        .char_data(tty_byte),
        .host_overflow(host_overflow), .cpu_overflow(cpu_overflow)
    );

    // Same timings as the known EX20-05.16 HDMI PLL solution:
    // 1280x720 active, 1650x750 total, nominal 74.25 MHz pixel clock.
    reg [11:0] hcount = 12'd0, vcount = 12'd0;
    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            hcount <= 0; vcount <= 0;
        end else if (hcount == 12'd1649) begin
            hcount <= 0;
            if (vcount == 12'd749) vcount <= 0;
            else vcount <= vcount + 1'b1;
        end else hcount <= hcount + 1'b1;
    end
    wire hs = hcount < 12'd40;
    wire vs = vcount < 12'd5;
    wire de = hcount >= 12'd260 && hcount < 12'd1540 &&
              vcount >= 12'd25 && vcount < 12'd745;
    wire [10:0] px = hcount - 12'd260;
    wire [9:0] py = vcount - 12'd25;

    wire [23:0] bgr;
    pikosol20k_renderer u_scene (
        .pix_clk(pix_clk), .resetn_pixel(resetn_pixel),
        .de(de), .px(px), .py(py),
        .char_valid(tty_valid), .char_ready(tty_ready),
        .char_data(tty_byte), .cpu_clk(clk27), .resetn_cpu(resetn_cpu),
        .gfx_valid(pix_gfx_valid), .gfx_index(pix_gfx_index),
        .gfx_value(pix_gfx_value), .leds(led_mask_pixel),
        .bgr_out(bgr)
    );

    // The text renderer has two synchronous video pipeline stages.
    reg hs_d1, hs_d2, vs_d1, vs_d2, de_d1, de_d2;
    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            hs_d1<=0; hs_d2<=0;
            vs_d1<=0; vs_d2<=0;
            de_d1<=0; de_d2<=0;
        end else begin
            hs_d1<=hs; hs_d2<=hs_d1;
            vs_d1<=vs; vs_d2<=vs_d1;
            de_d1<=de; de_d2<=de_d1;
        end
    end
    DVI_TX_Top u_hdmi (
        .I_rst_n(pix_reset_request_n),
        .I_serial_clk(serial_clk), .I_rgb_clk(pix_clk),
        .I_rgb_vs(vs_d2), .I_rgb_hs(hs_d2), .I_rgb_de(de_d2),
        .I_rgb_r(bgr[7:0]), .I_rgb_g(bgr[15:8]), .I_rgb_b(bgr[23:16]),
        .O_tmds_clk_p(tmds_clk_p), .O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_d_p), .O_tmds_data_n(tmds_d_n)
    );
    wire _unused = host_overflow ^ cpu_overflow;
endmodule
