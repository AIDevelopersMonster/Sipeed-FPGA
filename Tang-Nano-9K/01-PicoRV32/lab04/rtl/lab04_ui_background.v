// PiKoSoL LAB-04.3.1A. SVO pixel-domain background without an extra clock domain.
// SPDX-License-Identifier: MIT
module lab04_ui_background (
    input wire clk_pixel, input wire resetn_pixel,
    input wire s_axis_tvalid, output wire s_axis_tready,
    input wire [23:0] s_axis_tdata, input wire [0:0] s_axis_tuser,
    output wire m_axis_tvalid, input wire m_axis_tready,
    output wire [23:0] m_axis_tdata, output wire [0:0] m_axis_tuser
);
    reg [9:0] x;
    reg [8:0] y;
    wire advance = s_axis_tvalid && s_axis_tready;
    assign s_axis_tready=m_axis_tready;
    assign m_axis_tvalid=s_axis_tvalid;
    assign m_axis_tuser=s_axis_tuser;
    // Consistent {blue, green, red} lanes, same format as existing SVO.
    assign m_axis_tdata = (y == 55 || y == 433) ? 24'h566050 :
                          y < 56 ? 24'h24221b :
                          y >= 434 ? 24'h242b1b :
                          x >= 400 ? 24'h211b15 : 24'h15100c;
    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            x <= 0;
            y <= 0;
        end else if (advance) begin
            if (s_axis_tuser[0]) begin
                x <= 10'd1;
                y <= 0;
            end else if (x == 639) begin
                x <= 0;
                y <= (y == 479) ? 0 : y + 1'b1;
            end else x <= x + 1'b1;
        end
    end
    wire _unused = ^s_axis_tdata;
endmodule
