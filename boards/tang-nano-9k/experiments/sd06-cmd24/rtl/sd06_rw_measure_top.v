// RESOURCE/TIMING-ONLY top. NOT FOR PHYSICAL PROGRAMMING.
// Force retention of the complete CMD17/CMD24 reader/writer datapath by
// keeping a synthetically reachable LBA (0xFFFFFFFE) while preserving
// ordinary board pin names. No physical test card or scratch LBA is approved.
// The build script deletes all generated programming files after PnR.
// SPDX-License-Identifier: MIT
module sd06_rw_measure_top (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,
    input wire sd_miso,
    output wire uart_tx,
    output wire sd_sck,
    output wire sd_mosi,
    output wire sd_cs_n,
    output wire [5:0] led_n
);
    sd06_rw_bridge_top #(
        .WRITE_FIRST_LBA(32'hFFFFFFFE),
        .WRITE_LAST_LBA(32'hFFFFFFFE)
    ) u_sd_rw (
        .clk(clk),
        .reset_n(reset_n),
        .uart_rx(uart_rx),
        .sd_miso(sd_miso),
        .uart_tx(uart_tx),
        .sd_sck(sd_sck),
        .sd_mosi(sd_mosi),
        .sd_cs_n(sd_cs_n),
        .led_n(led_n)
    );
endmodule
