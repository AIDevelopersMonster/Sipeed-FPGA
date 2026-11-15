// PR25 USB PHYSICAL ATTACH LITE 02
// 640x480 DVI diagnostic: passive sense on USB-A D+ (L6), D- (K6).
// NO USB host, NO USB packet transmission, NO driven USB data pins.
// Compared to 01: no static KonSol text ROM, no dynamic character ROM.
`include "config.svh"

module lab_top
# (
    parameter clk_mhz = 50,
              w_key = 4, w_sw = 8, w_led = 8, w_digit = 8, w_gpio = 100,
              screen_width = 640, screen_height = 480,
              w_red = 4, w_green = 4, w_blue = 4,
              w_x = $clog2(screen_width), w_y = $clog2(screen_height)
)
(
    input clk, input slow_clk, input rst,
    input [w_key-1:0] key, input [w_sw-1:0] sw,
    output logic [w_led-1:0] led,
    output logic [7:0] abcdefgh,
    output logic [w_digit-1:0] digit,
    input [w_x-1:0] x, input [w_y-1:0] y,
    output logic [w_red-1:0] red,
    output logic [w_green-1:0] green,
    output logic [w_blue-1:0] blue,
    input [23:0] mic, output [15:0] sound,
    input uart_rx, output uart_tx,
    inout [w_gpio-1:0] gpio
);

    assign led = '0;
    assign abcdefgh = '0;
    assign digit = '0;
    assign sound = '0;
    assign uart_tx = 1'b1;
    assign gpio = {w_gpio{1'bz}}; // all USB and other GPIO pins are HI-Z

    // state bit 0 = D+ (L6), bit 1 = D- (K6)
    logic [1:0] metastable = 2'b00;
    logic [1:0] sampled    = 2'b00;
    logic [1:0] candidate  = 2'b00;
    logic [1:0] stable     = 2'b00;
    logic [18:0] filter_count = 19'd0;
    logic [15:0] event_count = 16'd0;
    logic [24:0] heartbeat_count = 25'd0;
    logic heartbeat = 1'b0;

    localparam integer FILTER_TICKS = clk_mhz * 10000;   // 10 ms @ 50 MHz
    localparam integer BEAT_TICKS   = clk_mhz * 500000;  // 0.5 s @ 50 MHz

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            metastable <= 2'b00;
            sampled <= 2'b00;
            candidate <= 2'b00;
            stable <= 2'b00;
            filter_count <= 19'd0;
            event_count <= 16'd0;
            heartbeat_count <= 25'd0;
            heartbeat <= 1'b0;
        end else begin
            metastable <= {gpio[31], gpio[30]};
            sampled <= metastable;
            if (sampled != candidate) begin
                candidate <= sampled;
                filter_count <= 19'd0;
            end else if (filter_count < FILTER_TICKS-1) begin
                filter_count <= filter_count + 19'd1;
            end else if (stable != candidate) begin
                stable <= candidate;
                event_count <= event_count + 16'd1;
            end
            if (heartbeat_count == BEAT_TICKS-1) begin
                heartbeat_count <= 25'd0;
                heartbeat <= ~heartbeat;
            end else heartbeat_count <= heartbeat_count + 25'd1;
        end
    end

    // Tiny hex/0/1 seven-segment glyph. Replaces ~1000 lines of character ROM.
    function automatic logic seg_on(
        input logic [3:0] n,
        input logic [6:0] xx, yy
    );
        logic [6:0] seg; // a,b,c,d,e,f,g in bits 6..0
        begin
            case (n)
                4'h0: seg = 7'b1111110;
                4'h1: seg = 7'b0110000;
                4'h2: seg = 7'b1101101;
                4'h3: seg = 7'b1111001;
                4'h4: seg = 7'b0110011;
                4'h5: seg = 7'b1011011;
                4'h6: seg = 7'b1011111;
                4'h7: seg = 7'b1110000;
                4'h8: seg = 7'b1111111;
                4'h9: seg = 7'b1111011;
                4'hA: seg = 7'b1110111;
                4'hB: seg = 7'b0011111;
                4'hC: seg = 7'b1001110;
                4'hD: seg = 7'b0111101;
                4'hE: seg = 7'b1001111;
                4'hF: seg = 7'b1000111;
                default: seg = 7'b0000000;
            endcase
            seg_on =
                (seg[6] && yy < 7'd7 && xx >= 7'd7 && xx < 7'd41) ||
                (seg[5] && xx >= 7'd41 && yy >= 7'd7 && yy < 7'd35) ||
                (seg[4] && xx >= 7'd41 && yy >= 7'd37 && yy < 7'd65) ||
                (seg[3] && yy >= 7'd65 && yy < 7'd72 && xx >= 7'd7 && xx < 7'd41) ||
                (seg[2] && xx < 7'd7 && yy >= 7'd37 && yy < 7'd65) ||
                (seg[1] && xx < 7'd7 && yy >= 7'd7 && yy < 7'd35) ||
                (seg[0] && yy >= 7'd33 && yy < 7'd40 && xx >= 7'd7 && xx < 7'd41);
        end
    endfunction

    wire [9:0] px = x;
    wire [9:0] py = y;
    wire dplus_digit =
        (px >= 10'd510 && px < 10'd558 && py >= 10'd95 && py < 10'd167) &&
        seg_on({3'b0,stable[0]}, 7'(px-10'd510), 7'(py-10'd95));
    wire dminus_digit =
        (px >= 10'd510 && px < 10'd558 && py >= 10'd233 && py < 10'd305) &&
        seg_on({3'b0,stable[1]}, 7'(px-10'd510), 7'(py-10'd233));

    wire e3 = (px>=10'd156 && px<10'd204 && py>=10'd404 && py<10'd476) &&
        seg_on(event_count[15:12],7'(px-10'd156),7'(py-10'd404));
    wire e2 = (px>=10'd228 && px<10'd276 && py>=10'd404 && py<10'd476) &&
        seg_on(event_count[11:8],7'(px-10'd228),7'(py-10'd404));
    wire e1 = (px>=10'd300 && px<10'd348 && py>=10'd404 && py<10'd476) &&
        seg_on(event_count[7:4],7'(px-10'd300),7'(py-10'd404));
    wire e0 = (px>=10'd372 && px<10'd420 && py>=10'd404 && py<10'd476) &&
        seg_on(event_count[3:0],7'(px-10'd372),7'(py-10'd404));

    logic [23:0] rgb;
    always_comb begin
        rgb = 24'h07162C; // background
        // Header and heartbeat: right upper corner changes every 0.5s.
        if (py < 10'd50) rgb = 24'h16406C;
        if (py >= 10'd15 && py < 10'd35 && px >= 10'd40 && px < 10'd500)
            rgb = 24'h23D8EA;
        if (py >= 10'd10 && py < 10'd42 && px >= 10'd565 && px < 10'd615)
            rgb = heartbeat ? 24'h78FF6A : 24'h143E2A;
        // D+ (FIRST/UPPER panel): small left raw square, big filtered panel.
        if (py >= 10'd67 && py < 10'd187 && px >= 10'd32 && px < 10'd608)
            rgb = 24'h123049;
        if (py >= 10'd93 && py < 10'd165 && px >= 10'd52 && px < 10'd110)
            rgb = sampled[0] ? 24'hEFAB33 : 24'h642A36;
        if (py >= 10'd93 && py < 10'd165 && px >= 10'd132 && px < 10'd478)
            rgb = stable[0] ? 24'h168C43 : 24'h24475C;
        if (dplus_digit) rgb = 24'hF5F7FB;
        // D- (SECOND/LOWER panel): blue for D- high.
        if (py >= 10'd205 && py < 10'd325 && px >= 10'd32 && px < 10'd608)
            rgb = 24'h123049;
        if (py >= 10'd231 && py < 10'd303 && px >= 10'd52 && px < 10'd110)
            rgb = sampled[1] ? 24'hEFAB33 : 24'h642A36;
        if (py >= 10'd231 && py < 10'd303 && px >= 10'd132 && px < 10'd478)
            rgb = stable[1] ? 24'h1684BA : 24'h24475C;
        if (dminus_digit) rgb = 24'hF5F7FB;
        // Final stable line-state band: 00=blue, 01=green, 10=cyan, 11=red.
        if (py >= 10'd343 && py < 10'd386 && px >= 10'd32 && px < 10'd608) begin
            case (stable)
                2'b00: rgb = 24'h234E9B;
                2'b01: rgb = 24'h1C9B49;
                2'b10: rgb = 24'h078FAB;
                default: rgb = 24'hCA414A;
            endcase
        end
        // 16-bit attach/disconnect event counter (HEX) in 4 large digits.
        if (e3 || e2 || e1 || e0) rgb = 24'hF6D36F;
        if (px >= screen_width || py >= screen_height) rgb = 24'h000000;
    end
    assign red = w_red'(rgb[23:16]);
    assign green = w_green'(rgb[15:8]);
    assign blue = w_blue'(rgb[7:0]);
endmodule
