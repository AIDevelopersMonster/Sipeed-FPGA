// PiKoSoL LAB-04.3: two CPU-defined graphic rectangles.
// Pixel stream is pass-through except pixels covered by enabled rectangles.
// Staging registers are written from the *pixel-domain* mailbox event.
// A write to index 15 requests a coherent frame-boundary snapshot: changes
// are not visible until next accepted SOF; no half-updated geometry in-frame.
// B is composited above A. LED HUD after this module remains topmost.
// Coordinates: 10-bit x/y, dimensions 8-bit w/h, BGR888 color.
// Control bits: 0=enable, 1=outline-only, 2=checker-pattern fill.
// SPDX-License-Identifier: MIT
module lab04_graphics_osd #(
    parameter integer H_ACTIVE = 640,
    parameter integer V_ACTIVE = 480
)(
    input wire clk_pixel,
    input wire resetn_pixel,
    input wire event_valid,
    input wire [3:0] event_index,
    input wire [23:0] event_value,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire [23:0] s_axis_tdata,
    input wire [0:0] s_axis_tuser,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire [23:0] m_axis_tdata,
    output wire [0:0] m_axis_tuser
);
    reg [9:0] xpos, ypos;
    wire fire = s_axis_tvalid && s_axis_tready;
    wire [9:0] px = s_axis_tuser[0] ? 10'd0 : xpos;
    wire [9:0] py = s_axis_tuser[0] ? 10'd0 : ypos;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;

    reg [9:0] ax_stage, ay_stage, bx_stage, by_stage;
    reg [7:0] aw_stage, ah_stage, bw_stage, bh_stage;
    reg [23:0] ac_stage, bc_stage;
    reg [2:0] actrl_stage, bctrl_stage;
    reg [9:0] ax_frame, ay_frame, bx_frame, by_frame;
    reg [7:0] aw_frame, ah_frame, bw_frame, bh_frame;
    reg [23:0] ac_frame, bc_frame;
    reg [2:0] actrl_frame, bctrl_frame;
    reg commit_pending;

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            xpos <= 0; ypos <= 0; commit_pending <= 1'b0;
            ax_stage <= 0; ay_stage <= 0; aw_stage <= 0; ah_stage <= 0;
            ac_stage <= 0; actrl_stage <= 0;
            bx_stage <= 0; by_stage <= 0; bw_stage <= 0; bh_stage <= 0;
            bc_stage <= 0; bctrl_stage <= 0;
            ax_frame <= 0; ay_frame <= 0; aw_frame <= 0; ah_frame <= 0;
            ac_frame <= 0; actrl_frame <= 0;
            bx_frame <= 0; by_frame <= 0; bw_frame <= 0; bh_frame <= 0;
            bc_frame <= 0; bctrl_frame <= 0;
        end else begin
            if (event_valid) begin
                case (event_index)
                    4'd0: ax_stage <= event_value[9:0];
                    4'd1: ay_stage <= event_value[9:0];
                    4'd2: aw_stage <= event_value[7:0];
                    4'd3: ah_stage <= event_value[7:0];
                    4'd4: ac_stage <= event_value;
                    4'd5: actrl_stage <= event_value[2:0];
                    4'd8: bx_stage <= event_value[9:0];
                    4'd9: by_stage <= event_value[9:0];
                    4'd10: bw_stage <= event_value[7:0];
                    4'd11: bh_stage <= event_value[7:0];
                    4'd12: bc_stage <= event_value;
                    4'd13: bctrl_stage <= event_value[2:0];
                    4'd15: commit_pending <= 1'b1;
                    default: ;
                endcase
            end
            if (fire) begin
                if (s_axis_tuser[0]) begin
                    xpos <= 10'd1;
                    ypos <= 10'd0;
                    if (commit_pending) begin
                        ax_frame <= ax_stage; ay_frame <= ay_stage;
                        aw_frame <= aw_stage; ah_frame <= ah_stage;
                        ac_frame <= ac_stage; actrl_frame <= actrl_stage;
                        bx_frame <= bx_stage; by_frame <= by_stage;
                        bw_frame <= bw_stage; bh_frame <= bh_stage;
                        bc_frame <= bc_stage; bctrl_frame <= bctrl_stage;
                        commit_pending <= (event_valid && event_index == 4'd15);
                    end
                end else if (xpos == H_ACTIVE - 1) begin
                    xpos <= 0;
                    ypos <= (ypos == V_ACTIVE-1) ? 0 : ypos + 1'b1;
                end else begin
                    xpos <= xpos + 1'b1;
                end
            end
        end
    end

    wire hit_a = actrl_frame[0] && (aw_frame != 0) && (ah_frame != 0) &&
        ({1'b0,px} >= {1'b0,ax_frame}) &&
        ({1'b0,px} < ({1'b0,ax_frame} + {3'b0,aw_frame})) &&
        ({1'b0,py} >= {1'b0,ay_frame}) &&
        ({1'b0,py} < ({1'b0,ay_frame} + {3'b0,ah_frame}));
    wire hit_b = bctrl_frame[0] && (bw_frame != 0) && (bh_frame != 0) &&
        ({1'b0,px} >= {1'b0,bx_frame}) &&
        ({1'b0,px} < ({1'b0,bx_frame} + {3'b0,bw_frame})) &&
        ({1'b0,py} >= {1'b0,by_frame}) &&
        ({1'b0,py} < ({1'b0,by_frame} + {3'b0,bh_frame}));
    wire border_a = hit_a && ((px - ax_frame < 2) ||
        (ax_frame + {2'b0,aw_frame} - px <= 2) ||
        (py - ay_frame < 2) || (ay_frame + {2'b0,ah_frame} - py <= 2));
    wire border_b = hit_b && ((px - bx_frame < 2) ||
        (bx_frame + {2'b0,bw_frame} - px <= 2) ||
        (py - by_frame < 2) || (by_frame + {2'b0,bh_frame} - py <= 2));
    wire paint_a = hit_a && (!actrl_frame[1] || border_a) &&
        (!actrl_frame[2] || (px[3] ^ py[3]) || border_a);
    wire paint_b = hit_b && (!bctrl_frame[1] || border_b) &&
        (!bctrl_frame[2] || (px[3] ^ py[3]) || border_b);
    assign m_axis_tdata = paint_b ? bc_frame : paint_a ? ac_frame : s_axis_tdata;
endmodule
