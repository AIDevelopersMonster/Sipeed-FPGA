// LAB-04.2 CPU OSER10 reset distribution experiment, v0.1.5.
// 27 MHz oscillator -> Gowin rPLL (126 MHz) -> CLKDIV/5 (25.2 MHz).
// Each clock domain has its own async-assert / synchronous-release reset.
// An asynchronous PLL lock loss or external button asserts ALL resets.
// The 126 MHz release is locally re-registered for three OSER10 lanes.
// In particular, a 27 MHz reset must not directly enable pixel-clock FFs.
// Third-party Gowin IP is unmodified. SPDX-License-Identifier: MIT
module lab04_video_clocks (
    input wire clk27,
    input wire reset_n,
    output wire clk_pixel,
    output wire clk_5x_pixel,
    output wire video_resetn,        // synchronous deassert in clk27 domain
    output wire pixel_resetn,        // synchronous deassert in clk_pixel domain
    output wire serdes_resetn,       // synchronous deassert in clk_5x_pixel domain
    output wire pll_locked
);
    Gowin_rPLL u_rpll (
        .clkin(clk27),
        .clkout(clk_5x_pixel),
        .lock(pll_locked)
    );

    // The divided clock must also restart when external reset is asserted.
    wire pll_run_n = reset_n && pll_locked;
    Gowin_CLKDIV u_div5 (
        .hclkin(clk_5x_pixel),
        .resetn(pll_run_n),
        .clkout(clk_pixel)
    );

    // The 3-bit registers start in reset even before clocks have started.
    // Do not merge these chains: the clocks have DIFFERENT frequencies.
    (* syn_keep = 1 *) reg [2:0] sys_release_q = 3'b000;
    (* syn_keep = 1 *) reg [2:0] pixel_release_q = 3'b000;
    (* syn_keep = 1 *) reg [2:0] serdes_release_q = 3'b000;

    always @(posedge clk27 or negedge pll_run_n) begin
        if (!pll_run_n) sys_release_q <= 3'b000;
        else sys_release_q <= {sys_release_q[1:0], 1'b1};
    end
    always @(posedge clk_pixel or negedge pll_run_n) begin
        if (!pll_run_n) pixel_release_q <= 3'b000;
        else pixel_release_q <= {pixel_release_q[1:0], 1'b1};
    end
    always @(posedge clk_5x_pixel or negedge pll_run_n) begin
        if (!pll_run_n) serdes_release_q <= 3'b000;
        else serdes_release_q <= {serdes_release_q[1:0], 1'b1};
    end

    assign video_resetn = sys_release_q[2];
    assign pixel_resetn = pixel_release_q[2];
    // Restore the rising-edge 126 MHz release. A negative-edge extra stage
    // caused STA recovery to degrade from -0.244 ns to -1.498 ns on CPU PnR.
    // The HDMI wrapper adds three preserved, per-lane local reset FFs.
    // Always review actual post-route Gowin STA before loading SRAM.
    assign serdes_resetn = serdes_release_q[2];
endmodule
