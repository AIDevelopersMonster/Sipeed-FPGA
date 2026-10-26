// KonSol RetroStation RS-004 - K-BLOCKS RGB v0.1.0
// Original falling-block game; Tang Nano 9K, 640x480 HDMI raster stream.
// No PicoRV32, external RAM, SD, commercial game ROM or framebuffer.
// SPDX-License-Identifier: MIT
module kblocks_rgb_core #(
    parameter integer GRAVITY_FRAMES = 30,
    parameter integer SOFT_DROP_FRAMES = 3,
    parameter integer MOVE_REPEAT_FRAMES = 5
) (
    input  wire        clk,
    input  wire        reset_n,
    input  wire [7:0]  rx_byte,
    input  wire        rx_valid,
    output reg  [1:0]  palette,
    output wire        ai_on,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,
    input  wire [23:0] s_axis_tdata,
    input  wire [0:0]  s_axis_tuser,
    output wire        m_axis_tvalid,
    input  wire        m_axis_tready,
    output wire [23:0] m_axis_tdata,
    output wire [0:0]  m_axis_tuser
);
    localparam [1:0] ST_READY=2'd0, ST_PLAY=2'd1,
                     ST_CLEAR=2'd2, ST_OVER=2'd3;
    localparam [4:0] FIELD_COLS=5'd10, FIELD_ROWS=5'd20;
    localparam [9:0] FIELD_X=10'd240, FIELD_Y=10'd64;

    assign ai_on = 1'b0;
    assign s_axis_tready = m_axis_tready;
    assign m_axis_tvalid = s_axis_tvalid;
    assign m_axis_tuser = s_axis_tuser;
    wire accept_pixel = s_axis_tvalid && m_axis_tready;
    wire frame_tick   = accept_pixel && s_axis_tuser[0];

    // Each row stores ten occupancy bits. Colours are generated procedurally.
    // This deliberately avoids a 640x480 framebuffer and external memory.
    reg [9:0] field_rows [0:19];
    reg [1:0] state;
    reg [2:0] piece_kind;
    reg [1:0] piece_rot;
    reg [4:0] piece_x, piece_y;
    reg [4:0] clear_row;
    reg [3:0] lines_ones, lines_tens; // displayed decimal 00...99
    reg [7:0] fall_ctr, move_ctr, blink;
    reg left_held, right_held, down_held;
    reg rotate_pending, start_pending, restart_pending;

    function [2:0] next_kind;
        input [2:0] kind;
        begin next_kind = kind == 3'd6 ? 3'd0 : kind + 3'd1; end
    endfunction

    // Four 4x4 orientations per piece, normalized toward the top/left.
    // Row r occupies bits [4*r+3 : 4*r]. Every mask has exactly four cells.
    function [15:0] shape_mask;
        input [2:0] kind;
        input [1:0] rotation;
        begin
            case ({kind,rotation})
                5'd00: shape_mask=16'h000F; // I, 0
                5'd01: shape_mask=16'h1111;
                5'd02: shape_mask=16'h000F;
                5'd03: shape_mask=16'h1111;
                5'd04: shape_mask=16'h0033; // O
                5'd05: shape_mask=16'h0033;
                5'd06: shape_mask=16'h0033;
                5'd07: shape_mask=16'h0033;
                5'd08: shape_mask=16'h0072; // T
                5'd09: shape_mask=16'h0131;
                5'd10: shape_mask=16'h0027;
                5'd11: shape_mask=16'h0232;
                5'd12: shape_mask=16'h0074; // L
                5'd13: shape_mask=16'h0311;
                5'd14: shape_mask=16'h0017;
                5'd15: shape_mask=16'h0223;
                5'd16: shape_mask=16'h0071; // J
                5'd17: shape_mask=16'h0113;
                5'd18: shape_mask=16'h0047;
                5'd19: shape_mask=16'h0322;
                5'd20: shape_mask=16'h0036; // S
                5'd21: shape_mask=16'h0231;
                5'd22: shape_mask=16'h0036;
                5'd23: shape_mask=16'h0231;
                5'd24: shape_mask=16'h0063; // Z
                5'd25: shape_mask=16'h0132;
                5'd26: shape_mask=16'h0063;
                5'd27: shape_mask=16'h0132;
                default: shape_mask=16'h0000;
            endcase
        end
    endfunction

    // Four 10-bit row intersections, rather than sixteen independently
    // addressed cells: much smaller combinational mux network for the 9K.
    // The 14-bit shift catches cells that would extend past column 9.
    function can_place;
        input [2:0] test_kind;
        input [1:0] test_rot;
        input [4:0] test_x, test_y;
        reg [15:0] mask;
        reg [13:0] shifted;
        integer row, yy;
        begin
            can_place = 1'b1;
            mask = shape_mask(test_kind, test_rot);
            for (row=0; row<4; row=row+1) begin
                shifted = {10'd0,mask[row*4 +: 4]} << test_x;
                if (|mask[row*4 +: 4]) begin
                    yy = test_y + row;
                    if (yy >= 20 || |shifted[13:10])
                        can_place = 1'b0;
                    else if ((field_rows[yy] & shifted[9:0]) != 0)
                        can_place = 1'b0;
                end
            end
        end
    endfunction

    wire [15:0] active_shape = shape_mask(piece_kind,piece_rot);
    wire [7:0] fall_period = down_held ? SOFT_DROP_FRAMES : GRAVITY_FRAMES;
    wire gravity_due = (fall_ctr >= fall_period - 8'd1);

    // UART: a/A = left down/up, d/D = right down/up, s/S = down down/up,
    // w = rotate once, p/Space = start, r = restart, x = release all,
    // 1..4 = palettes. Events latch until a frame boundary (no lost clicks).
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            palette<=0; left_held<=0; right_held<=0; down_held<=0;
            rotate_pending<=0; start_pending<=0; restart_pending<=0;
        end else begin
            if (frame_tick) begin
                start_pending<=0;
                restart_pending<=0;
                if (state != ST_PLAY || !gravity_due) rotate_pending<=0;
            end
            if (rx_valid) begin
                case (rx_byte)
                    8'h61: left_held<=1;  // a
                    8'h41: left_held<=0;  // A
                    8'h64: right_held<=1; // d
                    8'h44: right_held<=0; // D
                    8'h73: down_held<=1;  // s
                    8'h53: down_held<=0;  // S
                    8'h77: rotate_pending<=1; // w (edge-triggered)
                    8'h70, 8'h20: start_pending<=1; // p / Space
                    8'h72: begin
                        restart_pending<=1;
                        left_held<=0; right_held<=0; down_held<=0;
                        rotate_pending<=0;
                    end
                    8'h78: begin
                        left_held<=0; right_held<=0; down_held<=0;
                    end
                    8'h31: palette<=0;
                    8'h32: palette<=1;
                    8'h33: palette<=2;
                    8'h34: palette<=3;
                    default: ;
                endcase
            end
        end
    end

    integer k;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            for (k=0; k<20; k=k+1) field_rows[k]<=10'd0;
            state<=ST_READY;
            piece_kind<=0; piece_rot<=0; piece_x<=5'd3; piece_y<=0;
            clear_row<=5'd19; lines_ones<=0; lines_tens<=0;
            fall_ctr<=0; move_ctr<=0; blink<=0;
        end else if (frame_tick && restart_pending) begin
            for (k=0; k<20; k=k+1) field_rows[k]<=10'd0;
            state<=ST_READY;
            piece_kind<=0; piece_rot<=0; piece_x<=5'd3; piece_y<=0;
            clear_row<=5'd19; lines_ones<=0; lines_tens<=0;
            fall_ctr<=0; move_ctr<=0; blink<=0;
        end else begin
            if (frame_tick) blink<=blink+8'd1;
            case (state)
                ST_READY: begin
                    if (frame_tick && start_pending) begin
                        state<=ST_PLAY;
                        piece_x<=5'd3; piece_y<=0;
                        piece_kind<=0; piece_rot<=0;
                        fall_ctr<=0; move_ctr<=0;
                    end
                end
                ST_PLAY: begin
                    if (frame_tick) begin
                        if (move_ctr != 0) move_ctr<=move_ctr-8'd1;
                        if (gravity_due) begin
                            fall_ctr<=0;
                            if (can_place(piece_kind,piece_rot,piece_x,piece_y+5'd1)) begin
                                piece_y<=piece_y+5'd1;
                            end else begin
                                // Lock each of four possible rows EXACTLY ONCE.
                                // Multiple cells in a row are combined before writing.
                                for (k=0; k<4; k=k+1) begin
                                    if (|active_shape[k*4 +: 4]) begin
                                        if (piece_y+k < 20)
                                            field_rows[piece_y+k] <=
                                                field_rows[piece_y+k] |
                                                ({6'd0,active_shape[k*4 +: 4]} << piece_x);
                                    end
                                end
                                clear_row<=5'd19;
                                state<=ST_CLEAR;
                            end
                        end else begin
                            fall_ctr<=fall_ctr+8'd1;
                            if (rotate_pending &&
                                    can_place(piece_kind,piece_rot+2'd1,piece_x,piece_y))
                                piece_rot<=piece_rot+2'd1;
                            else if (move_ctr==0 && left_held && !right_held &&
                                    piece_x!=0 &&
                                    can_place(piece_kind,piece_rot,piece_x-5'd1,piece_y)) begin
                                piece_x<=piece_x-5'd1;
                                move_ctr<=MOVE_REPEAT_FRAMES;
                            end else if (move_ctr==0 && right_held && !left_held &&
                                    piece_x<5'd9 &&
                                    can_place(piece_kind,piece_rot,piece_x+5'd1,piece_y)) begin
                                piece_x<=piece_x+5'd1;
                                move_ctr<=MOVE_REPEAT_FRAMES;
                            end
                        end
                    end
                end
                ST_CLEAR: begin
                    // Scan the board bottom-to-top at *pixel clock* rate.
                    // A full row is removed in one cycle, then the same index
                    // is tested again (correctly handles adjacent full rows).
                    if (field_rows[clear_row]==10'h3FF) begin
                        for (k=19; k>0; k=k-1)
                            if (k<=clear_row) field_rows[k]<=field_rows[k-1];
                        field_rows[0]<=10'd0;
                        if (lines_ones==4'd9) begin
                            lines_ones<=0;
                            lines_tens<=lines_tens==4'd9 ? 4'd0 : lines_tens+4'd1;
                        end else lines_ones<=lines_ones+4'd1;
                    end else if (clear_row!=0) begin
                        clear_row<=clear_row-5'd1;
                    end else begin
                        // Spawn a new piece after compression is complete.
                        if (can_place(next_kind(piece_kind),2'd0,5'd3,5'd0)) begin
                            piece_kind<=next_kind(piece_kind);
                            piece_rot<=0; piece_x<=5'd3; piece_y<=0;
                            fall_ctr<=0; move_ctr<=0;
                            state<=ST_PLAY;
                        end else state<=ST_OVER;
                    end
                end
                ST_OVER: begin
                    // r resets all rows; p also starts a completely fresh game.
                    if (frame_tick && start_pending) begin
                        for (k=0; k<20; k=k+1) field_rows[k]<=10'd0;
                        state<=ST_PLAY;
                        piece_kind<=0; piece_rot<=0; piece_x<=5'd3; piece_y<=0;
                        fall_ctr<=0; move_ctr<=0;
                        lines_ones<=0; lines_tens<=0;
                    end
                end
                default: state<=ST_READY;
            endcase
        end
    end

    // Match the published SVO/LAB-04 raster contract. tuser[0] marks
    // the FIRST active pixel, so pixel (0,0) is explicitly selected.
    reg [9:0] scan_x,scan_y;
    wire [9:0] px = s_axis_tuser[0] ? 10'd0 : scan_x;
    wire [9:0] py = s_axis_tuser[0] ? 10'd0 : scan_y;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin scan_x<=0; scan_y<=0; end
        else if (accept_pixel) begin
            if (s_axis_tuser[0]) begin scan_x<=10'd1; scan_y<=0; end
            else if (scan_x==10'd639) begin
                scan_x<=0;
                scan_y<=scan_y==10'd479 ? 10'd0 : scan_y+10'd1;
            end else scan_x<=scan_x+10'd1;
        end
    end

    wire inside_field = px>=FIELD_X && px<FIELD_X+10'd160 &&
                        py>=FIELD_Y && py<FIELD_Y+10'd320;
    wire [9:0] cell_px = px-FIELD_X;
    wire [9:0] cell_py = py-FIELD_Y;
    wire [3:0] cell_col = cell_px[7:4];
    wire [4:0] cell_row = cell_py[8:4];
    wire [4:0] relx = {1'b0,cell_col}-piece_x;
    wire [4:0] rely = cell_row-piece_y;
    wire locked_pixel = inside_field && field_rows[cell_row][cell_col];
    wire falling_pixel = inside_field && state==ST_PLAY &&
                         cell_col>=piece_x && cell_col<piece_x+5'd4 &&
                         cell_row>=piece_y && cell_row<piece_y+5'd4 &&
                         active_shape[{rely[1:0],relx[1:0]}];
    wire grid_line = inside_field && (cell_px[3:0]==0 || cell_py[3:0]==0);
    wire field_border = px>=FIELD_X-10'd4 && px<FIELD_X+10'd164 &&
                        py>=FIELD_Y-10'd4 && py<FIELD_Y+10'd324 &&
                        !inside_field;

    function [23:0] piece_color;
        input [2:0] kind;
        begin case (kind)
            0: piece_color=24'h19D9FD;
            1: piece_color=24'hFFED46;
            2: piece_color=24'hB969FF;
            3: piece_color=24'hFF993D;
            4: piece_color=24'h587CFF;
            5: piece_color=24'h55F179;
            default: piece_color=24'hFF5978;
        endcase end
    endfunction

    function [6:0] digit_segs;
        input [3:0] value;
        begin case (value)
            0:digit_segs=7'b1111110; 1:digit_segs=7'b0110000;
            2:digit_segs=7'b1101101; 3:digit_segs=7'b1111001;
            4:digit_segs=7'b0110011; 5:digit_segs=7'b1011011;
            6:digit_segs=7'b1011111; 7:digit_segs=7'b1110000;
            8:digit_segs=7'b1111111; 9:digit_segs=7'b1111011;
            default:digit_segs=7'b0000001;
        endcase end
    endfunction
    function digit_pixel;
        input [3:0] value;
        input [9:0] dx,dy;
        reg [6:0] seg;
        begin
            seg=digit_segs(value);
            digit_pixel = (seg[6] && dy<4 && dx>=4 && dx<24) ||
                          (seg[5] && dx>=24 && dy>=4 && dy<23) ||
                          (seg[4] && dx>=24 && dy>=25 && dy<44) ||
                          (seg[3] && dy>=44 && dx>=4 && dx<24) ||
                          (seg[2] && dx<4 && dy>=25 && dy<44) ||
                          (seg[1] && dx<4 && dy>=4 && dy<23) ||
                          (seg[0] && dy>=22 && dy<26 && dx>=4 && dx<24);
        end
    endfunction
    wire digits_pixel =
        (px>=10'd458 && px<10'd486 && py>=10'd138 && py<10'd186 &&
         digit_pixel(lines_tens,px-10'd458,py-10'd138)) ||
        (px>=10'd493 && px<10'd521 && py>=10'd138 && py<10'd186 &&
         digit_pixel(lines_ones,px-10'd493,py-10'd138));

    // Small "NEXT" preview. The next shape is deterministic: I O T L J S Z.
    wire [15:0] preview_shape = shape_mask(next_kind(piece_kind),2'd0);
    wire preview_box = px>=10'd455 && px<10'd519 &&
                       py>=10'd257 && py<10'd321;
    wire [5:0] pdx = px-10'd455;
    wire [5:0] pdy = py-10'd257;
    wire [1:0] pcol = pdx[5:4];
    wire [1:0] prow = pdy[5:4];
    wire preview_pixel = preview_box && preview_shape[{prow,pcol}];
    wire preview_grid = preview_box && (pdx[3:0]==0 || pdy[3:0]==0);

    // Status stripes and visually distinct title block; no copied game assets.
    wire title_back=px>=10'd28 && px<10'd198 && py>=10'd60 && py<10'd108;
    wire title_stripe=title_back && (px<10'd36 || py<10'd67);
    wire title_k=title_back && (px>=10'd55 && px<10'd63 && py>=10'd73 && py<10'd100 ||
        (px>=10'd63 && px<10'd89 && py>=10'd83 && py<10'd90));
    wire info_bar=px>=10'd451 && px<10'd547 && py>=10'd107 && py<10'd113;
    wire over_banner=state==ST_OVER && blink[4] &&
                     px>=10'd175 && px<10'd465 && py>=10'd405 && py<10'd426;
    wire ready_banner=state==ST_READY && blink[4] &&
                     px>=10'd239 && px<10'd401 && py>=10'd405 && py<10'd426;
    wire edge=px<10'd3 || px>=10'd637 || py<10'd3 || py>=10'd477;
    wire [23:0] background=palette==0 ? 24'h10152A :
                           palette==1 ? 24'h09151B :
                           palette==2 ? 24'h25121C : 24'h171021;
    wire [23:0] fixed_color=palette==0 ? 24'h315ACB :
                            palette==1 ? 24'h2CBAA5 :
                            palette==2 ? 24'hD66A75 : 24'hB17EDE;
    assign m_axis_tdata =
          falling_pixel ? piece_color(piece_kind) :
          locked_pixel ? fixed_color :
          digits_pixel ? 24'hF9ED8C :
          preview_pixel ? piece_color(next_kind(piece_kind)) :
          (field_border || title_stripe || info_bar) ? 24'h50A5FF :
          over_banner ? 24'hFF4D60 :
          ready_banner ? 24'h73EAC8 :
          title_k ? 24'hFCDE72 :
          (grid_line || preview_grid) ? 24'h253354 :
          edge ? 24'h405070 : background;
    wire _unused = ^s_axis_tdata;
endmodule
