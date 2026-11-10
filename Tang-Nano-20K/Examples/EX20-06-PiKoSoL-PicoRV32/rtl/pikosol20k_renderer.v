// PiKoSoL 20K: native 1280x720 text and graphics compositor.
// Target: GW2AR-18C with a PicoRV32 legacy command-compatible source.
// Output is BGR888, delayed two pixel cycles for alignment with HDMI control.
// Development candidate: requires RTL simulation, Gowin PnR/STA and board test.
// SPDX-License-Identifier: MIT
module pikosol20k_renderer (
    input wire pix_clk,
    input wire resetn_pixel,
    input wire de,
    input wire [10:0] px,
    input wire [9:0] py,
    input wire char_valid,
    output wire char_ready,
    input wire [7:0] char_data,
    input wire cpu_clk,
    input wire resetn_cpu,
    input wire gfx_valid,
    input wire [5:0] gfx_index,
    input wire [23:0] gfx_value,
    input wire [5:0] leds,
    output wire [23:0] bgr_out
);
    // 160 columns * 64 backing rows. Exactly 60 rows visible at 8x12.
    localparam integer COLS = 160;
    localparam integer RING_ROWS = 64;
    localparam integer VRAM_BYTES = COLS*RING_ROWS;
    reg [7:0] text_mem [0:VRAM_BYTES-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg [7:0] font_mem [0:2047] /* synthesis syn_romstyle = "block_rom" */;
    initial $readmemh("lab04_font_8x12.hex", font_mem);

    reg terminal_mode;
    reg [5:0] cursor_row, view_base;
    reg [7:0] cursor_col;
    reg clearing, full_clear;
    reg [13:0] clear_offset;
    reg [7:0] clear_col;
    reg [5:0] clear_row;
    wire [5:0] next_row = cursor_row + 6'd1;
    wire [5:0] bottom_row = view_base + 6'd59;
    wire [13:0] clear_row_base = ({8'd0,clear_row} << 7) +
                                ({8'd0,clear_row} << 5);
    wire [13:0] cursor_row_base = ({8'd0,cursor_row} << 7) +
                                 ({8'd0,cursor_row} << 5);

    wire tty_event;
    wire [7:0] tty_byte;
    lab04_tty_byte_cdc u_byte_cdc (
        .clk_sys(cpu_clk), .resetn_sys(resetn_cpu),
        .char_valid(char_valid), .char_ready(char_ready), .char_data(char_data),
        .clk_pixel(pix_clk), .resetn_pixel(resetn_pixel),
        .pixel_accept(!clearing),
        .event_valid(tty_event), .event_byte(tty_byte)
    );

    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            terminal_mode <= 1'b1;
            cursor_row <= 6'd0;
            cursor_col <= 8'd0;
            view_base <= 6'd0;
            clearing <= 1'b1;
            full_clear <= 1'b1;
            clear_offset <= 14'd0;
            clear_col <= 8'd0;
            clear_row <= 6'd0;
        end else if (clearing) begin
            // Sequential clear preserves BSRAM inference (no massive reset mux).
            if (full_clear) begin
                text_mem[clear_offset] <= 8'h20;
                if (clear_offset == VRAM_BYTES-1) clearing <= 1'b0;
                else clear_offset <= clear_offset + 14'd1;
            end else begin
                text_mem[clear_row_base + {6'd0,clear_col}] <= 8'h20;
                if (clear_col == COLS-1) clearing <= 1'b0;
                else clear_col <= clear_col + 8'd1;
            end
        end else if (tty_event) begin
            case (tty_byte)
                8'h0e: terminal_mode <= 1'b1; // TERM
                8'h0f: terminal_mode <= 1'b0; // GFX
                8'h0c: begin // CLS / FF
                    terminal_mode <= terminal_mode;
                    cursor_row <= 6'd0; view_base <= 6'd0;
                    cursor_col <= 8'd0;
                    clearing <= 1'b1; full_clear <= 1'b1;
                    clear_offset <= 14'd0;
                end
                8'h0d: cursor_col <= 8'd0;
                8'h0a: begin
                    cursor_col <= 8'd0;
                    cursor_row <= next_row;
                    if (cursor_row == bottom_row) view_base <= view_base + 6'd1;
                    clear_row <= next_row;
                    clear_col <= 8'd0;
                    full_clear <= 1'b0;
                    clearing <= 1'b1;
                end
                8'h08, 8'h7f: if (cursor_col != 0) begin
                    cursor_col <= cursor_col - 8'd1;
                    text_mem[cursor_row_base + {6'd0,cursor_col} - 14'd1] <= 8'h20;
                end
                default: if (tty_byte >= 8'h20 && tty_byte <= 8'h7e) begin
                    text_mem[cursor_row_base + {6'd0,cursor_col}] <= tty_byte;
                    if (cursor_col == COLS-1) begin
                        cursor_col <= 8'd0;
                        cursor_row <= next_row;
                        if (cursor_row == bottom_row) view_base <= view_base + 6'd1;
                        clear_row <= next_row;
                        clear_col <= 8'd0;
                        full_clear <= 1'b0;
                        clearing <= 1'b1;
                    end else cursor_col <= cursor_col + 8'd1;
                end
            endcase
        end
    end

    // Eight 20K object descriptors; no two-object hard limit in the renderer.
    // Compatible bank: legacy 9K object A/B slots and COMMIT at index 15;
    // indices 16..61 can be reached from the extended 20K MMIO window.
    reg [11:0] ox_stage [0:7], oy_stage [0:7];
    reg [11:0] ow_stage [0:7], oh_stage [0:7];
    reg [23:0] color_stage [0:7];
    reg [2:0] mode_stage [0:7];
    reg [11:0] ox_live [0:7], oy_live [0:7];
    reg [11:0] ow_live [0:7], oh_live [0:7];
    reg [23:0] color_live [0:7];
    reg [2:0] mode_live [0:7];
    reg commit_pending;
    integer i;
    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            commit_pending <= 1'b0;
            for (i=0; i<8; i=i+1) begin
                ox_stage[i] <= 0; oy_stage[i] <= 0;
                ow_stage[i] <= 0; oh_stage[i] <= 0;
                color_stage[i] <= 0; mode_stage[i] <= 0;
                ox_live[i] <= 0; oy_live[i] <= 0;
                ow_live[i] <= 0; oh_live[i] <= 0;
                color_live[i] <= 0; mode_live[i] <= 0;
            end
        end else begin
            if (gfx_valid) begin
                if (gfx_index == 6'd15 || gfx_index == 6'd63)
                    commit_pending <= 1'b1;
                else begin
                    case (gfx_index[2:0])
                        3'd0: ox_stage[gfx_index[5:3]] <= gfx_value[11:0];
                        3'd1: oy_stage[gfx_index[5:3]] <= gfx_value[11:0];
                        3'd2: ow_stage[gfx_index[5:3]] <= gfx_value[11:0];
                        3'd3: oh_stage[gfx_index[5:3]] <= gfx_value[11:0];
                        3'd4: color_stage[gfx_index[5:3]] <= gfx_value;
                        3'd5: mode_stage[gfx_index[5:3]] <= gfx_value[2:0];
                        default: ;
                    endcase
                end
            end
            if (de && px == 0 && py == 0 && commit_pending) begin
                for (i=0; i<8; i=i+1) begin
                    ox_live[i] <= ox_stage[i]; oy_live[i] <= oy_stage[i];
                    ow_live[i] <= ow_stage[i]; oh_live[i] <= oh_stage[i];
                    color_live[i] <= color_stage[i];
                    mode_live[i] <= mode_stage[i];
                end
                commit_pending <= (gfx_valid &&
                                  (gfx_index == 6'd15 || gfx_index == 6'd63));
            end
        end
    end

    // Graphic selection and LED HUD are combinational; one pixel register
    // follows before synchronous text RAM/font pipeline and the HDMI PHY.
    reg [23:0] background;
    reg shape_hit, shape_border;
    integer obj;
    integer led_idx;
    always @* begin
        background = 24'h201810;
        shape_hit = 1'b0;
        shape_border = 1'b0;
        if (!terminal_mode) begin
            background = 24'h302018;
            for (obj=0; obj<8; obj=obj+1) begin
                shape_hit = mode_live[obj][0] &&
                    (ow_live[obj] != 0 && oh_live[obj] != 0) &&
                    ({1'b0,px} >= {1'b0,ox_live[obj]}) &&
                    ({1'b0,py} >= {1'b0,oy_live[obj]}) &&
                    ({1'b0,px} - {1'b0,ox_live[obj]} < {1'b0,ow_live[obj]}) &&
                    ({1'b0,py} - {1'b0,oy_live[obj]} < {1'b0,oh_live[obj]});
                shape_border = shape_hit &&
                    ((px - ox_live[obj] < 2) ||
                     (py - oy_live[obj] < 2) ||
                     (ox_live[obj] + ow_live[obj] - px <= 2) ||
                     (oy_live[obj] + oh_live[obj] - py <= 2));
                if (shape_hit && (!mode_live[obj][1] || shape_border) &&
                    (!mode_live[obj][2] || px[3] ^ py[3] || shape_border))
                    background = color_live[obj];
            end
            // Native 720p LED overlay: six bars at top right.
            for (led_idx=0; led_idx<6; led_idx=led_idx+1) begin
                if (px >= 11'd862 + led_idx*63 &&
                    px < 11'd910 + led_idx*63 &&
                    py >= 10'd20 && py < 10'd54)
                    background = leds[led_idx] ? 24'h30E030 : 24'h505050;
            end
        end
    end

    wire [5:0] text_row = py / 12;
    wire [3:0] glyph_y = py % 12;
    wire [5:0] physical_row = view_base + text_row;
    wire [13:0] text_addr = ({8'd0,physical_row} << 7) +
                            ({8'd0,physical_row} << 5) + {6'd0,px[10:3]};
    wire text_region = terminal_mode || py >= 10'd624;

    reg [7:0] char_q;
    reg [7:0] font_row_q;
    reg [3:0] glyph_y_a;
    reg [2:0] char_bit_a, char_bit_b;
    reg [23:0] background_a, background_b;
    reg text_a, text_b;
    reg term_a, term_b;
    always @(posedge pix_clk) begin
        if (de && !clearing) char_q <= text_mem[text_addr];
        font_row_q <= font_mem[{char_q[6:0],glyph_y_a}];
    end
    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            background_a <= 0; background_b <= 0;
            char_bit_a <= 0; char_bit_b <= 0; glyph_y_a <= 0;
            text_a <= 0; text_b <= 0; term_a <= 1; term_b <= 1;
        end else begin
            // Stage A: address synchronous character RAM and capture scene.
            background_a <= background;
            text_a <= de && text_region && !clearing;
            term_a <= terminal_mode;
            char_bit_a <= px[2:0];
            glyph_y_a <= glyph_y;
            // Stage B: align glyph ROM access with the scene and text bit.
            background_b <= background_a;
            text_b <= text_a;
            term_b <= term_a;
            char_bit_b <= char_bit_a;
        end
    end
    wire ink = font_row_q[7-char_bit_b];
    assign bgr_out = text_b ?
        (ink ? 24'hF0F0F0 : (term_b ? 24'h201810 : 24'h181818)) :
        background_b;
endmodule
