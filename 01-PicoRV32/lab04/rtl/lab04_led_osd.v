// PiKoSoL LAB-04.2 v0.1.6: six LED bars on the SVO pixel stream.
// Does not touch timing, TMDS encoding, terminal or SERDES. All logic runs on
// clk_pixel; SOF resets the active-pixel position. Ready/valid are transparent.
// 640x480V only for this experiment. SVO pixel order is {BLUE,GREEN,RED}.
// SPDX-License-Identifier: MIT
module lab04_led_osd #(
    parameter integer H_ACTIVE = 640,
    parameter integer V_ACTIVE = 480
)(
    input wire clk_pixel,
    input wire resetn_pixel,
    input wire [5:0] mask_pixel,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire [23:0] s_axis_tdata,
    input wire [0:0] s_axis_tuser,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire [23:0] m_axis_tdata,
    output wire [0:0] m_axis_tuser
);
    // The original SOF beat is coordinate (0,0), even after a stall.
    reg [9:0] xpos;
    reg [9:0] ypos;
    reg [5:0] frame_mask;
    wire [9:0] px = s_axis_tuser[0] ? 10'd0 : xpos;
    wire [9:0] py = s_axis_tuser[0] ? 10'd0 : ypos;
    wire fire = s_axis_tvalid && s_axis_tready;

    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            xpos <= 10'd0;
            ypos <= 10'd0;
            frame_mask <= 6'b0;
        end else if (fire) begin
            if (s_axis_tuser[0]) begin
                xpos <= 10'd1;
                ypos <= 10'd0;
                frame_mask <= mask_pixel; // one coherent snapshot per frame
            end else if (xpos == H_ACTIVE-1) begin
                xpos <= 10'd0;
                ypos <= (ypos == V_ACTIVE-1) ? 10'd0 : ypos + 1'b1;
            end else begin
                xpos <= xpos + 1'b1;
            end
        end
    end

    // Upper video/terminal remains unchanged. HUD is near screen bottom:
    // six cells left-to-right correspond exactly to LED1..LED6 (mask bits 0..5).
    reg cell_hit;
    reg cell_on;
    reg [9:0] left_x;
    always @* begin
        cell_hit = 1'b0;
        cell_on = 1'b0;
        left_x = 10'd0;
        if      ((px >= 10'd30)  && (px < 10'd110)) begin
            cell_hit = 1'b1; cell_on = frame_mask[0]; left_x = 10'd30;
        end else if ((px >= 10'd130) && (px < 10'd210)) begin
            cell_hit = 1'b1; cell_on = frame_mask[1]; left_x = 10'd130;
        end else if ((px >= 10'd230) && (px < 10'd310)) begin
            cell_hit = 1'b1; cell_on = frame_mask[2]; left_x = 10'd230;
        end else if ((px >= 10'd330) && (px < 10'd410)) begin
            cell_hit = 1'b1; cell_on = frame_mask[3]; left_x = 10'd330;
        end else if ((px >= 10'd430) && (px < 10'd510)) begin
            cell_hit = 1'b1; cell_on = frame_mask[4]; left_x = 10'd430;
        end else if ((px >= 10'd530) && (px < 10'd610)) begin
            cell_hit = 1'b1; cell_on = frame_mask[5]; left_x = 10'd530;
        end
    end
    wire hud_back = px >= 10'd16 && px < 10'd624 &&
                    py >= V_ACTIVE-78 && py < V_ACTIVE-8;
    wire in_cell = cell_hit && py >= V_ACTIVE-59 && py < V_ACTIVE-23;
    wire cell_border = in_cell &&
        ((px < left_x+10'd3) || (px >= left_x+10'd77) ||
         (py < V_ACTIVE-56) || (py >= V_ACTIVE-26));

    // All color constants in SVO BGR byte order.
    assign m_axis_tdata = cell_border ? 24'hE0E0E0 :
                          in_cell ? (cell_on ? 24'h20E030 : 24'h303030) :
                          hud_back ? 24'h201008 : s_axis_tdata;
endmodule
