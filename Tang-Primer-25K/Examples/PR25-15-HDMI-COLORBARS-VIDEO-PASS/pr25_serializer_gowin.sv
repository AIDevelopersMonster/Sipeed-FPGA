// GW5A serializer adapter, extracted from the Gowin-specific OSER10 path
// in thisiseth/tang-primer-25k-spi-io/src/fpga/spi_io_bridge/src/hdmi/serializer.sv.
// Source project (c) thisiseth, MIT. See LICENSE and README_RU.md.
// No Xilinx/Altera macros and no behavioural fallback: fail early if OSER10
// is unavailable in the selected GOWIN target device.
module serializer #(
    parameter integer NUM_CHANNELS = 3,
    parameter real VIDEO_RATE = 74.25e6
)(
    input  logic clk_pixel,
    input  logic clk_pixel_x5,
    input  logic reset,
    input  logic [9:0] tmds_internal [NUM_CHANNELS-1:0],
    output logic [2:0] tmds,
    output logic tmds_clock
);
    // The reference Gowin implementation uses OSER10 for the three data lanes
    // and directly drives the differential TMDS clock from the pixel clock.
    // The output pins are mapped with IO_TYPE=LVCMOS33D in the CST.
    for (genvar ch = 0; ch < 3; ch = ch + 1) begin : gen_oser10
        OSER10 u_oser10 (
            .Q     (tmds[ch]),
            .D0    (tmds_internal[ch][0]),
            .D1    (tmds_internal[ch][1]),
            .D2    (tmds_internal[ch][2]),
            .D3    (tmds_internal[ch][3]),
            .D4    (tmds_internal[ch][4]),
            .D5    (tmds_internal[ch][5]),
            .D6    (tmds_internal[ch][6]),
            .D7    (tmds_internal[ch][7]),
            .D8    (tmds_internal[ch][8]),
            .D9    (tmds_internal[ch][9]),
            .PCLK  (clk_pixel),
            .FCLK  (clk_pixel_x5),
            .RESET (reset)
        );
    end
    assign tmds_clock = clk_pixel;
endmodule
