// Caption overlay for the colour bars: "Terence Ang" and a running SMPTE drop-frame
// timecode HH:MM:SS;FF, white 32x32 text (8x8 font x4) in a black box.
// Combinational in (x, y), as hdmi_tx wants video_rgb in the same cycle.

// 59.94 fps drop-frame timecode (BCD). Frame labels 00-03 are skipped at the start of
// every minute except minutes 00, 10, 20 ...; at exactly 27 MHz / (858 x 525) this tracks
// wall-clock time.
module timecode_df (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        tick,           // one pulse per video frame
    output reg  [31:0] bcd = 0         // {h1,h0,m1,m0,s1,s0,f1,f0}
);
    wire [3:0] h1 = bcd[31:28], h0 = bcd[27:24], m1 = bcd[23:20], m0 = bcd[19:16],
               s1 = bcd[15:12], s0 = bcd[11:8],  f1 = bcd[7:4],   f0 = bcd[3:0];
    always @(posedge clk)
        if (!rst_n) bcd <= 0;
        else if (tick) begin
            if (f1 != 5 || f0 != 9)                         // next frame
                bcd[7:0] <= (f0 == 9) ? {f1 + 4'd1, 4'd0} : {f1, f0 + 4'd1};
            else if (s1 != 5 || s0 != 9) begin              // next second
                bcd[15:0] <= {(s0 == 9) ? {s1 + 4'd1, 4'd0} : {s1, s0 + 4'd1}, 8'h00};
            end else begin                                  // next minute
                bcd[15:8] <= 8'h00;
                bcd[7:0]  <= (m0 == 9) ? 8'h00 : 8'h04;     // drop 00-03 unless minute % 10 == 0
                if (m0 != 9)      bcd[19:16] <= m0 + 4'd1;
                else if (m1 != 5) bcd[23:16] <= {m1 + 4'd1, 4'd0};
                else begin                                  // next hour
                    bcd[23:16] <= 8'h00;
                    bcd[31:24] <= (h1 == 2 && h0 == 3) ? 8'h00 :
                                  (h0 == 9) ? {h1 + 4'd1, 4'd0} : {h1, h0 + 4'd1};
                end
            end
        end
endmodule

module overlay #(
    parameter [9:0] BOX_X0 = 168, BOX_X1 = 552,   // black box
    parameter [9:0] BOX_Y0 = 304, BOX_Y1 = 424,
    parameter [9:0] TXT_X0 = 184,                  // 11 chars x 32 px = 352 px, centred in 720
    parameter [9:0] NAME_Y = 320,
    parameter [9:0] TC_Y   = 376
) (
    input  wire [9:0]  x,
    input  wire [9:0]  y,
    input  wire [23:0] bg,
    input  wire [31:0] tc,             // timecode BCD
    output wire [23:0] rgb
);
    // glyph codes: 0-9 digits, then
    localparam C_COLON = 5'd10, C_SEMI = 5'd11, C_T = 5'd12, C_e = 5'd13, C_r = 5'd14,
               C_n = 5'd15, C_c = 5'd16, C_A = 5'd17, C_g = 5'd18, C_SP = 5'd19;

    function [63:0] glyph(input [4:0] c);   // 8 rows, row 0 in [63:56], MSB = left pixel
        case (c)
            5'd0:    glyph = 64'h3C666E7666663C00;
            5'd1:    glyph = 64'h1838181818187E00;
            5'd2:    glyph = 64'h3C66060C30607E00;
            5'd3:    glyph = 64'h3C66061C06663C00;
            5'd4:    glyph = 64'h0C1C3C6C7E0C0C00;
            5'd5:    glyph = 64'h7E607C0606663C00;
            5'd6:    glyph = 64'h3C66607C66663C00;
            5'd7:    glyph = 64'h7E660C1818181800;
            5'd8:    glyph = 64'h3C66663C66663C00;
            5'd9:    glyph = 64'h3C66663E06663C00;
            C_COLON: glyph = 64'h0018180018180000;
            C_SEMI:  glyph = 64'h0018180018183000;
            C_T:     glyph = 64'h7E18181818181800;
            C_e:     glyph = 64'h00003C667E603C00;
            C_r:     glyph = 64'h00007C6660606000;
            C_n:     glyph = 64'h00007C6666666600;
            C_c:     glyph = 64'h00003C6060603C00;
            C_A:     glyph = 64'h183C667E66666600;
            C_g:     glyph = 64'h00003E66663E067C;
            default: glyph = 64'h0;
        endcase
    endfunction

    function [4:0] name_char(input [3:0] i);   // "Terence Ang"
        case (i)
            4'd0: name_char = C_T;  4'd1: name_char = C_e;  4'd2: name_char = C_r;
            4'd3: name_char = C_e;  4'd4: name_char = C_n;  4'd5: name_char = C_c;
            4'd6: name_char = C_e;  4'd7: name_char = C_SP; 4'd8: name_char = C_A;
            4'd9: name_char = C_n;  4'd10: name_char = C_g; default: name_char = C_SP;
        endcase
    endfunction

    function [4:0] tc_char(input [3:0] i, input [31:0] t);   // HH:MM:SS;FF
        case (i)
            4'd0: tc_char = t[31:28];  4'd1: tc_char = t[27:24];  4'd2: tc_char = C_COLON;
            4'd3: tc_char = t[23:20];  4'd4: tc_char = t[19:16];  4'd5: tc_char = C_COLON;
            4'd6: tc_char = t[15:12];  4'd7: tc_char = t[11:8];   4'd8: tc_char = C_SEMI;
            4'd9: tc_char = t[7:4];    4'd10: tc_char = t[3:0];   default: tc_char = C_SP;
        endcase
    endfunction

    wire       in_box  = (x >= BOX_X0) && (x < BOX_X1) && (y >= BOX_Y0) && (y < BOX_Y1);
    wire [9:0] rx      = x - TXT_X0;
    wire       in_cols = (x >= TXT_X0) && (rx < 10'd352);
    wire       in_name = (y >= NAME_Y) && (y < NAME_Y + 32);
    wire       in_tc   = (y >= TC_Y)   && (y < TC_Y + 32);
    wire [9:0] ry      = y - (in_name ? NAME_Y : TC_Y);

    wire [4:0]  code  = in_name ? name_char(rx[8:5]) : tc_char(rx[8:5], tc);
    wire [63:0] g     = glyph(code);
    wire [7:0]  row   = g[63 - 8 * ry[4:2] -: 8];
    wire        lit   = in_cols && (in_name || in_tc) && row[3'd7 - rx[4:2]];

    assign rgb = lit ? 24'hFFFFFF : in_box ? 24'h000000 : bg;
endmodule
