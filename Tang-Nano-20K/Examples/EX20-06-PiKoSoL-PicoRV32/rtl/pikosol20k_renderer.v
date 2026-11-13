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
    input wire frame_start, // vertical blanking: raw raster (0,0)
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

    // GW2AR BSRAM: exactly ONE synchronous physical write port.  The old
    // parser had independent indexed writes for clear, backspace and chars.
    // Gowin could not infer BSRAM and expanded text_mem into 131072 FFs.
    // Multiplex the write address/data before a reset-free RAM write process.
    wire tty_printable = tty_event && tty_byte >= 8'h20 && tty_byte <= 8'h7e;
    wire tty_backspace = tty_event && (tty_byte == 8'h08 || tty_byte == 8'h7f)
                                     && cursor_col != 0;
    wire [13:0] ram_clear_addr = full_clear ? clear_offset :
                                   (clear_row_base + {6'd0,clear_col});
    wire [13:0] ram_char_addr = cursor_row_base + {6'd0,cursor_col};
    wire ram_wr_en = resetn_pixel && (clearing ||
                     (tty_printable || tty_backspace));
    wire [13:0] ram_wr_addr = clearing ? ram_clear_addr :
                       (tty_backspace ? (ram_char_addr-14'd1) : ram_char_addr);
    wire [7:0] ram_wr_data = (!clearing && tty_printable) ? tty_byte : 8'h20;

    // No reset or other procedural assignments to text_mem in this design.
    // One plain-clock write process, one plain-clock synchronous read process:
    // standard Gowin dual-port RAM inference (read-during-write unspecified).
    always @(posedge pix_clk) begin
        if (ram_wr_en) text_mem[ram_wr_addr] <= ram_wr_data;
    end

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
                if (clear_offset == VRAM_BYTES-1) clearing <= 1'b0;
                else clear_offset <= clear_offset + 14'd1;
            end else begin
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
                end
                default: if (tty_byte >= 8'h20 && tty_byte <= 8'h7e) begin
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
    reg [12:0] x_end_live [0:7], y_end_live [0:7];
    reg [12:0] x_left_border_live [0:7], y_top_border_live [0:7];
    reg [12:0] x_right_border_live [0:7], y_bottom_border_live [0:7];
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
                x_end_live[i] <= 0; y_end_live[i] <= 0;
                x_left_border_live[i] <= 0; y_top_border_live[i] <= 0;
                x_right_border_live[i] <= 0; y_bottom_border_live[i] <= 0;
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
            if (frame_start && commit_pending) begin
                for (i=0; i<8; i=i+1) begin
                    ox_live[i] <= ox_stage[i]; oy_live[i] <= oy_stage[i];
                    ow_live[i] <= ow_stage[i]; oh_live[i] <= oh_stage[i];
                    color_live[i] <= color_stage[i];
                    mode_live[i] <= mode_stage[i];
                    x_end_live[i] <= {1'b0,ox_stage[i]} + {1'b0,ow_stage[i]};
                    y_end_live[i] <= {1'b0,oy_stage[i]} + {1'b0,oh_stage[i]};
                    x_left_border_live[i] <= {1'b0,ox_stage[i]} + 13'd2;
                    y_top_border_live[i] <= {1'b0,oy_stage[i]} + 13'd2;
                    x_right_border_live[i] <= {1'b0,ox_stage[i]} + {1'b0,ow_stage[i]} - 13'd2;
                    y_bottom_border_live[i] <= {1'b0,oy_stage[i]} + {1'b0,oh_stage[i]} - 13'd2;
                end
                commit_pending <= (gfx_valid &&
                                  (gfx_index == 6'd15 || gfx_index == 6'd63));
            end
        end
    end

    // Native 1280x720 graphics + text pipeline.
    // Stage 1: eight independent hit tests and text RAM address.
    // Stage 2: color priority mux and synchronous character BSRAM read.
    // Stage 3: font ROM read and final color/character alignment.
    // One coordinate register in the top precedes these three stages.
    // Frame COMMIT is during blanking, before any active pixel.
    wire [12:0] x13 = {2'd0,px};
    wire [12:0] y13 = {3'd0,py};
    reg [7:0] object_hit_s1;
    genvar obj;
    generate for (obj=0;obj<8;obj=obj+1) begin : hit_gen
        wire inside = mode_live[obj][0] && (ow_live[obj] != 0) &&
            (oh_live[obj] != 0) &&
            (x13 >= {1'b0,ox_live[obj]}) &&
            (x13 < x_end_live[obj]) &&
            (y13 >= {1'b0,oy_live[obj]}) &&
            (y13 < y_end_live[obj]);
        wire border = (x13 < x_left_border_live[obj]) ||
            (x13 >= x_right_border_live[obj]) ||
            (y13 < y_top_border_live[obj]) ||
            (y13 >= y_bottom_border_live[obj]);
        wire visible = inside && (!mode_live[obj][1] || border) &&
            (!mode_live[obj][2] || (px[3] ^ py[3]) || border);
        always @(posedge pix_clk or negedge resetn_pixel) begin
            if (!resetn_pixel) object_hit_s1[obj] <= 1'b0;
            else object_hit_s1[obj] <= de && !terminal_mode && visible;
        end
    end endgenerate

    reg hud_match_comb, hud_on_comb;
    integer led_idx;
    always @* begin
        hud_match_comb = 1'b0;
        hud_on_comb = 1'b0;
        for (led_idx=0;led_idx<6;led_idx=led_idx+1) begin
            if (px >= 11'd862 + led_idx*63 &&
                px < 11'd910 + led_idx*63 &&
                py >= 10'd20 && py < 10'd54) begin
                hud_match_comb = 1'b1;
                hud_on_comb = leds[led_idx];
            end
        end
    end
    reg hud_match_s1, hud_on_s1;
    wire [5:0] text_row = py / 12;
    wire [3:0] glyph_y = py % 12;
    wire [5:0] physical_row = view_base + text_row;
    wire [13:0] text_addr = ({8'd0,physical_row} << 7) +
                            ({8'd0,physical_row} << 5) + {6'd0,px[10:3]};
    wire text_region = terminal_mode || py >= 10'd624;
    reg [13:0] text_addr_s1;
    reg [3:0] glyph_y_s1, glyph_y_s2;
    reg [2:0] bit_s1, bit_s2, bit_s3;
    reg text_s1, text_s2, text_s3;
    reg term_s1, term_s2, term_s3;
    reg [23:0] background_s2, background_s3;
    reg [7:0] char_q, font_row_q;

    // Highest object index wins; no eight-level priority chain between
    // pixel coordinates and the first pipeline register.
    reg [23:0] selected_rgb;
    always @* begin
        selected_rgb = 24'h302018;
        casez (object_hit_s1)
            8'b1???????: selected_rgb = color_live[7];
            8'b01??????: selected_rgb = color_live[6];
            8'b001?????: selected_rgb = color_live[5];
            8'b0001????: selected_rgb = color_live[4];
            8'b00001???: selected_rgb = color_live[3];
            8'b000001??: selected_rgb = color_live[2];
            8'b0000001?: selected_rgb = color_live[1];
            8'b00000001: selected_rgb = color_live[0];
            default: ;
        endcase
    end

    // Reset-free RAM read process retains Gowin BSRAM and font ROM inference.
    always @(posedge pix_clk) begin
        if (text_s1) char_q <= text_mem[text_addr_s1];
        font_row_q <= font_mem[{char_q[6:0],glyph_y_s2}];
    end
    always @(posedge pix_clk or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            hud_match_s1 <= 0; hud_on_s1 <= 0;
            text_addr_s1 <= 0;
            glyph_y_s1 <= 0; glyph_y_s2 <= 0;
            bit_s1 <= 0; bit_s2 <= 0; bit_s3 <= 0;
            text_s1 <= 0; text_s2 <= 0; text_s3 <= 0;
            term_s1 <= 1; term_s2 <= 1; term_s3 <= 1;
            background_s2 <= 0; background_s3 <= 0;
        end else begin
            hud_match_s1 <= de && !terminal_mode && hud_match_comb;
            hud_on_s1 <= hud_on_comb;
            text_addr_s1 <= text_addr;
            glyph_y_s1 <= glyph_y;
            bit_s1 <= px[2:0];
            text_s1 <= de && text_region && !clearing;
            term_s1 <= terminal_mode;

            if (term_s1)
                background_s2 <= 24'h201810;
            else if (hud_match_s1)
                background_s2 <= hud_on_s1 ? 24'h30E030 : 24'h505050;
            else
                background_s2 <= selected_rgb;
            glyph_y_s2 <= glyph_y_s1;
            bit_s2 <= bit_s1;
            text_s2 <= text_s1;
            term_s2 <= term_s1;

            background_s3 <= background_s2;
            bit_s3 <= bit_s2;
            text_s3 <= text_s2;
            term_s3 <= term_s2;
        end
    end
    wire ink = font_row_q[7-bit_s3];
    assign bgr_out = text_s3 ?
        (ink ? 24'hF0F0F0 : (term_s3 ? 24'h201810 : 24'h181818)) :
        background_s3;
endmodule
