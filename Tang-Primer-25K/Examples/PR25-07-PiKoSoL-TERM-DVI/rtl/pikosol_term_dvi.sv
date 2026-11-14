// PiKoSoL 25K TERM-DVI v0.1; no SDRAM and no CPU.
// Video implementation and PLL adapted from thisiseth/tang-primer-25k-spi-io.
// This file is experimental: needs Gowin build and board verification.
module pikosol_term_dvi (
    input wire clk_50m,
    input wire uart_rx_pin,
    output wire uart_tx_pin,
    output wire [2:0] hdmi_tx_tmds,
    output wire hdmi_tx_tmds_clk,
    output wire led_ready,
    output wire led_done
);
wire pll_lock;
wire pixclk, pixclk5;
gowin_pll_hdmi_720 pll(
    .lock(pll_lock), .clkout0(pixclk), .clkout1(pixclk5),
    .clkin(clk_50m)
);
wire [10:0] px;
wire [9:0] py;
wire [10:0] fw, sw;
wire [9:0] fh, sh;
reg [23:0] rgb = 24'h000000;
wire [15:0] audio_silence [1:0];
assign audio_silence[0]=16'b0;
assign audio_silence[1]=16'b0;
hdmi #(
    .VIDEO_ID_CODE(4), .DVI_OUTPUT(1'b1)
) display(
    .clk_pixel_x5(pixclk5),
    .clk_pixel(pixclk),
    .clk_audio(pixclk),
    .reset(~pll_lock),
    .rgb(rgb),
    .audio_sample_word(audio_silence),
    .tmds(hdmi_tx_tmds),
    .tmds_clock(hdmi_tx_tmds_clk),
    .cx(px), .cy(py),
    .frame_width(fw), .frame_height(fh),
    .screen_width(sw), .screen_height(sh)
);
// 640x480 centered in 1280x720; 80x30 chars, 8x16 font.
// A synchronously read text RAM uses about 2400 bytes.
// Font is a 128-glyph x 16-line ROM reused from PiKoSoL LAB-04.
localparam COLS=80;
localparam ROWS=30;
reg [7:0] text_ram [0:2399];
reg [7:0] glyph_rom [0:2047];
// Initialize BRAMs from images. Avoid a 2400-iteration initial for-loop:
// GowinSynthesis EX3934 limits a single unrolled loop to 2000 iterations.
initial begin
    $readmemh("rtl/text_init.hex", text_ram);
    $readmemh("rtl/font_8x16.hex", glyph_rom);
end
wire [7:0] rx_byte;
wire rx_valid;
uart_rx #(.CLK_FRE(75), .BAUD_RATE(115200)) uart_receiver(
    .clk(pixclk), .rst_n(pll_lock),
    .rx_data(rx_byte), .rx_data_valid(rx_valid),
    .rx_data_ready(1'b1), .rx_pin(uart_rx_pin)
);
// TX held idle in v0.1: input-only terminal.
// No RX->TX loopback; use screen as the receive observable.
assign uart_tx_pin = 1'b1;
reg [6:0] cursor_col=0;
reg [4:0] cursor_row=1;
wire [11:0] write_addr = (cursor_row * COLS) + cursor_col;
always @(posedge pixclk) begin
    if (pll_lock && rx_valid) begin
        if(rx_byte == 8'h0d) begin
            cursor_col <= 0;
        end else if(rx_byte == 8'h0a) begin
            cursor_col <= 0;
            cursor_row <= (cursor_row == ROWS-1) ? 1 : cursor_row+1'b1;
        end else if(rx_byte == 8'h08) begin
            if(cursor_col != 0) cursor_col<=cursor_col-1'b1;
        end else if(rx_byte >= 8'h20 && rx_byte <= 8'h7e) begin
            text_ram[write_addr] <= rx_byte;
            if(cursor_col == COLS-1) begin
                cursor_col <= 0;
                cursor_row <= (cursor_row == ROWS-1) ? 1 : cursor_row+1'b1;
            end else cursor_col <= cursor_col+1'b1;
        end
    end
end
wire active_text = (px>=320 && px<960 && py>=120 && py<600);
wire [9:0] local_x = px - 11'd320;
wire [8:0] local_y = py - 10'd120;
wire [6:0] char_x = local_x[9:3];
wire [4:0] char_y = local_y[8:4];
wire [2:0] bit_x = local_x[2:0];
wire [3:0] bit_y = local_y[3:0];
// 2-clock pipeline (screen origin shifts by two pixels at most).
reg pixel_valid_1, pixel_valid_2;
reg [2:0] pix_bit_1,pix_bit_2;
reg [3:0] glyph_line_1;
reg [7:0] read_char=8'h20;
reg [7:0] glyph_line=0;
always @(posedge pixclk) begin
    pixel_valid_1 <= active_text;
    pix_bit_1 <= bit_x;
    glyph_line_1 <= bit_y;
    if (active_text) read_char <= text_ram[char_y*COLS+char_x];
    pixel_valid_2 <= pixel_valid_1;
    pix_bit_2 <= pix_bit_1;
    glyph_line <= glyph_rom[{read_char[6:0],glyph_line_1}];
    rgb <= (pixel_valid_2 && glyph_line[7-pix_bit_2]) ? 24'h4fffd6 : 24'h101427;
end
assign led_ready = pll_lock;
assign led_done = pll_lock;
endmodule
