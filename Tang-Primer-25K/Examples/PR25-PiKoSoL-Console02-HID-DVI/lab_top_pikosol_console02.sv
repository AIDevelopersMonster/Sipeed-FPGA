// PiKoSoL Console02 HID+DVI. Derived from board-demonstrated Tetris FIX2.
// External m1nl USB HID Host: Apache-2.0. Gameplay: own RTL.
// Preserves the demonstrated USB host and 640x480 Gowin DVI_TX,
// VGA timing, PLL and TMDS constraints. No UART, no CPU, no SDRAM.
// USB-A: L6 D+ (GPIO[30]), K6 D- (GPIO[31]). Active USB TX/RX: NOT passive.
// Status Console02: UNTESTED. No build or board result is claimed.
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
    // All GPIO except the two USB pins are high-impedance.
    // DO NOT add a blanket assign gpio='z'; USB core must drive SE0 and packets.
    genvar gi;
    generate
        for (gi = 0; gi < w_gpio; gi = gi + 1) begin : unused_gpio
            if ((gi != 30) && (gi != 31)) begin
                assign gpio[gi] = 1'bz;
            end
        end
    endgenerate

    // Diagnostic S1 switch, physical KEY[0] on H11 (active-high, hardware pulldown).
    // Power-up mode is PASSIVE: the host is explicitly held in reset/Hi-Z.
    // Each debounced S1 press toggles PASSIVE <-> HOST.
    logic host_mode = 1'b0;
    logic [1:0] key_sync = 2'b00;
    logic key_latched = 1'b0;
    logic [19:0] key_filter = 20'd0;
    localparam integer KEY_FILTER_TICKS = clk_mhz * 20000; // 20 ms
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            host_mode <= 1'b0;
            key_sync <= 2'b00;
            key_latched <= 1'b0;
            key_filter <= 20'd0;
        end else begin
            key_sync <= {key_sync[0], key[0]};
            if (key_sync[1] == key_latched) begin
                key_filter <= 20'd0;
            end else if (key_filter == KEY_FILTER_TICKS-1) begin
                key_latched <= key_sync[1];
                key_filter <= 20'd0;
                if (key_sync[1]) host_mode <= ~host_mode;
            end else key_filter <= key_filter + 20'd1;
        end
    end

    // The electrically proven, passive 2-bit detector from Lite 02.
    // Samples USB-A pins even with the Host present, but updates the filter
    // and attach counter ONLY while the host output is disabled.
    logic [1:0] metastable = 2'b00, sampled = 2'b00;
    logic [1:0] candidate = 2'b00, stable = 2'b00;
    logic [18:0] filter_count = 19'd0;
    logic [15:0] event_count = 16'd0;
    localparam integer FILTER_TICKS = clk_mhz * 10000; // 10 ms
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            metastable <= 0; sampled <= 0;
            candidate <= 0; stable <= 0;
            filter_count <= 0; event_count <= 0;
        end else begin
            metastable <= {gpio[31], gpio[30]};
            sampled <= metastable;
            if (!host_mode) begin
                if (sampled != candidate) begin
                    candidate <= sampled;
                    filter_count <= 0;
                end else if (filter_count < FILTER_TICKS-1) begin
                    filter_count <= filter_count + 1'b1;
                end else if (stable != candidate) begin
                    stable <= candidate;
                    event_count <= event_count + 1'b1;
                end
            end else begin
                // Do not count USB traffic as connect/disconnect events.
                candidate <= sampled;
                filter_count <= 0;
            end
        end
    end

    wire clk_usb;
    gowin_pll_usb pll60 (.clkin(clk), .clkout(clk_usb)); // PLLA 50 -> 60 MHz, see build script

    // Keep host reset asserted for ~21 ms after FPGA board reset.
    logic [20:0] reset_wait = 21'd0;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) reset_wait <= 21'd0;
        else if (!reset_wait[20]) reset_wait <= reset_wait + 21'd1;
    end
    logic [2:0] host_reset_sync = 3'b000;
    always_ff @(posedge clk_usb) begin
        if (!host_mode || !reset_wait[20] || rst) host_reset_sync <= 3'b000;
        else host_reset_sync <= {host_reset_sync[1:0], 1'b1};
    end
    // Gate immediately with host_mode, so S1 -> PASSIVE forces USB Hi-Z.
    wire host_reset_n = host_reset_sync[2] && host_mode && !rst;

    // m1nl redesign: native Low Speed (1.5 Mb/s) and Full Speed (12 Mb/s).
    // All USB pins remain physically high-impedance in PASSIVE mode.
    wire usb_dp_o, usb_dm_o, usb_oe, usb_busy;
    wire usb_line_drive = host_mode && host_reset_n && usb_oe;
    assign gpio[30] = usb_line_drive ? usb_dp_o : 1'bz;
    assign gpio[31] = usb_line_drive ? usb_dm_o : 1'bz;

    wire [1:0] hid_typ;
    wire hid_report, hid_error;
    wire [7:0] hid_mod, hid_key1, hid_key2, hid_key3, hid_key4, hid_key5, hid_key6;
    wire [7:0] mouse_buttons, mouse_dx, mouse_dy;
    wire [15:0] hid_vid, hid_pid;
    wire [63:0] raw_report, raw_regs;
    wire [9:0] hid_rom_addr;
    wire [3:0] hid_rom_data;
    wire hid_rom_en;
    assign hid_vid = raw_regs[15:0];  // {VID_H,VID_L}
    assign hid_pid = raw_regs[31:16]; // {PID_H,PID_L}

    usb_hid_host_rom hid_rom (
        .clk  (clk_usb),
        .addr (hid_rom_addr),
        .dout (hid_rom_data),
        .en   (hid_rom_en)
    );

    usb_hid_host #(.FULL_SPEED(1)) host (
        .clk         (clk_usb),
        .reset       (~host_reset_n),
        .cs          (1'b1),
        .usb_dp_i    (gpio[30]),
        .usb_dm_i    (gpio[31]),
        .usb_dp_o    (usb_dp_o),
        .usb_dm_o    (usb_dm_o),
        .usb_oe      (usb_oe),
        .typ         (hid_typ),
        .full_report (hid_report),
        .connerr     (hid_error),
        .busy        (usb_busy),
        .key_modifiers (hid_mod),
        .key_0       (hid_key1),
        .key_1       (hid_key2),
        .key_2       (hid_key3),
        .key_3       (hid_key4),
        .key_4       (hid_key5),
        .key_5       (hid_key6),
        .mouse_btn   (mouse_buttons),
        .mouse_dx    (mouse_dx),
        .mouse_dy    (mouse_dy),
        .dbg_hid_report (raw_report),
        .dbg_hid_regs   (raw_regs),
        .rom_addr    (hid_rom_addr),
        .rom_dout    (hid_rom_data),
        .rom_en      (hid_rom_en)
    );

    // Count actual USB Host TX start events, even if enumeration fails.
    // A zero TYPE with a nonzero TX count distinguishes activity from inactivity.
    logic usb_oe_delayed = 1'b0;
    logic tx_toggle_usb = 1'b0;
    always_ff @(posedge clk_usb) begin
        if (!host_reset_n) begin
            usb_oe_delayed <= 1'b0;
            tx_toggle_usb <= 1'b0;
        end else begin
            usb_oe_delayed <= usb_oe;
            if (usb_oe && !usb_oe_delayed) tx_toggle_usb <= ~tx_toggle_usb;
        end
    end
    // Capture the report and toggle in the 60 MHz domain. The payload is
    // held stable well before the 50 MHz side recognizes the synchronized toggle.
    logic [1:0] typ_usb_hold = 2'b00;
    logic [7:0] key1_usb_hold = 8'd0, key2_usb_hold = 8'd0,
                key3_usb_hold = 8'd0, key4_usb_hold = 8'd0,
                key5_usb_hold = 8'd0, key6_usb_hold = 8'd0, mod_usb_hold = 8'd0;
    logic report_toggle_usb = 1'b0;
    logic [24:0] beat_count_usb = 25'd0;
    logic beat_usb = 1'b0;
    always_ff @(posedge clk_usb) begin
        if (beat_count_usb == 25'd29999999) begin
            beat_count_usb <= 0;
            beat_usb <= ~beat_usb;
        end else beat_count_usb <= beat_count_usb + 1'b1;
    end

    always_ff @(posedge clk_usb) begin
        if (!host_reset_n) begin
            typ_usb_hold <= 2'b00;
            key1_usb_hold <= 8'd0;
            key2_usb_hold <= 8'd0;
            key3_usb_hold <= 8'd0; key4_usb_hold <= 8'd0;
            key5_usb_hold <= 8'd0; key6_usb_hold <= 8'd0;
            mod_usb_hold <= 8'd0;
            report_toggle_usb <= 1'b0;
        end else begin
            if (hid_report) begin
                typ_usb_hold <= hid_typ;
                // Type=1 is keyboard. Zero non-keyboard/connection-error report codes.
                key1_usb_hold <= hid_typ == 2'd1 ? hid_key1 : 8'd0;
                key2_usb_hold <= hid_typ == 2'd1 ? hid_key2 : 8'd0;
                key3_usb_hold <= hid_typ == 2'd1 ? hid_key3 : 8'd0;
                key4_usb_hold <= hid_typ == 2'd1 ? hid_key4 : 8'd0;
                key5_usb_hold <= hid_typ == 2'd1 ? hid_key5 : 8'd0;
                key6_usb_hold <= hid_typ == 2'd1 ? hid_key6 : 8'd0;
                mod_usb_hold <= hid_typ == 2'd1 ? hid_mod : 8'd0;
                report_toggle_usb <= ~report_toggle_usb;
            end
        end
    end

    logic [2:0] report_toggle_sync = 3'd0;
    logic [1:0] typ_meta = 2'd0, typ_stable = 2'd0;
    logic [15:0] vid_meta = 16'd0, vid_stable = 16'd0;
    logic [15:0] pid_meta = 16'd0, pid_stable = 16'd0;
    logic error_meta = 1'b0, error_stable = 1'b0;
    logic beat_meta = 1'b0, beat_stable = 1'b0;
    logic [15:0] report_count = 16'd0;
    logic [15:0] tx_count = 16'd0;
    logic [2:0] tx_toggle_sync = 3'd0;
    logic busy_meta = 1'b0, busy_stable = 1'b0;
    logic [7:0] last_key1 = 8'd0, last_key2 = 8'd0,
                last_key3 = 8'd0, last_key4 = 8'd0,
                last_key5 = 8'd0, last_key6 = 8'd0, last_mod = 8'd0;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            report_toggle_sync <= 3'd0;
            typ_meta <= 2'd0; typ_stable <= 2'd0;
            vid_meta <= 16'd0; vid_stable <= 16'd0;
            pid_meta <= 16'd0; pid_stable <= 16'd0;
            error_meta <= 1'b0; error_stable <= 1'b0;
            beat_meta <= 1'b0; beat_stable <= 1'b0;
            report_count <= 16'd0;
            tx_count <= 16'd0;
            tx_toggle_sync <= 3'd0;
            busy_meta <= 1'b0; busy_stable <= 1'b0;
            last_key1 <= 8'd0; last_key2 <= 8'd0;
            last_key3 <= 8'd0; last_key4 <= 8'd0;
            last_key5 <= 8'd0; last_key6 <= 8'd0; last_mod <= 8'd0;
        end else begin
            report_toggle_sync <= {report_toggle_sync[1:0], report_toggle_usb};
            typ_meta <= hid_typ; typ_stable <= typ_meta;
            vid_meta <= hid_vid; vid_stable <= vid_meta;
            pid_meta <= hid_pid; pid_stable <= pid_meta;
            error_meta <= hid_error; error_stable <= error_meta;
            beat_meta <= beat_usb; beat_stable <= beat_meta;
            tx_toggle_sync <= {tx_toggle_sync[1:0], tx_toggle_usb};
            if (tx_toggle_sync[2] != tx_toggle_sync[1]) tx_count <= tx_count + 16'd1;
            busy_meta <= usb_busy; busy_stable <= busy_meta;
            if (report_toggle_sync[2] != report_toggle_sync[1]) begin
                report_count <= report_count + 16'd1;
                last_key1 <= key1_usb_hold;
                last_key2 <= key2_usb_hold;
                last_key3 <= key3_usb_hold; last_key4 <= key4_usb_hold;
                last_key5 <= key5_usb_hold; last_key6 <= key6_usb_hold;
                last_mod <= mod_usb_hold;
            end
        end
    end

    // Report buses have settled by the cycle after the 3-stage toggle sync.
    // A one-cycle-delayed pulse is used for the game controls / F1 switch.
    wire new_report = report_toggle_sync[2] != report_toggle_sync[1];
    reg game_report_pulse = 1'b0;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) game_report_pulse <= 1'b0;
        else game_report_pulse <= new_report;
    end

    // Inside HOST: default GAME page. F1 toggles GAME <-> original HID05 DIAG.
    // The USB host is never reset by F1. S1 still switches PASSIVE <-> HOST.
    reg game_view = 1'b1;
    reg f1_prev = 1'b0;
    wire f1_held = last_key1 == 8'h3A || last_key2 == 8'h3A ||
                   last_key3 == 8'h3A || last_key4 == 8'h3A ||
                   last_key5 == 8'h3A || last_key6 == 8'h3A;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            game_view <= 1'b1;
            f1_prev <= 1'b0;
        end else if (!host_mode) begin
            f1_prev <= 1'b0;
        end else if (game_report_pulse) begin
            if (f1_held && !f1_prev) game_view <= ~game_view;
            f1_prev <= f1_held;
        end
    end

    // PiKoSoL Console02 replaces ONLY the Tetris game engine.
    // USB HID host, S1/F1 switches, DVI, PLL, pin mapping and HID diagnostics
    // are retained from hardware-demonstrated Tetris FIX2.
    wire [23:0] console_rgb;
    pikosol_console_core console (
        .clk(clk), .rst(rst), .enable(host_mode && game_view),
        .report_pulse(game_report_pulse && host_mode),
        .key0(last_key1), .modifiers(last_mod),
        .x(x), .y(y), .rgb(console_rgb)
    );

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

    // Render 7-segment glyph at a 48x72 pixel box. All boxes are nonoverlapping.
    function automatic logic place_digit(input logic [3:0] v,
                                         input logic [9:0] x0, input logic [9:0] y0,
                                         input logic [9:0] xpix, input logic [9:0] ypix);
        begin
            place_digit = xpix >= x0 && xpix < x0+10'd48 &&
                          ypix >= y0 && ypix < y0+10'd72 &&
                          seg_on(v, 7'(xpix-x0), 7'(ypix-y0));
        end
    endfunction

    wire type_digit = place_digit({2'b00,typ_stable}, 10'd82, 10'd62, px, py);
    wire error_digit = place_digit({3'b000,error_stable}, 10'd265, 10'd62, px, py);
    wire v3 = place_digit(vid_stable[15:12],10'd55, 10'd173,px,py);
    wire v2 = place_digit(vid_stable[11:8], 10'd117,10'd173,px,py);
    wire v1 = place_digit(vid_stable[7:4],  10'd179,10'd173,px,py);
    wire v0 = place_digit(vid_stable[3:0],  10'd241,10'd173,px,py);
    wire p3 = place_digit(pid_stable[15:12],10'd347,10'd173,px,py);
    wire p2 = place_digit(pid_stable[11:8], 10'd409,10'd173,px,py);
    wire p1 = place_digit(pid_stable[7:4],  10'd471,10'd173,px,py);
    wire p0 = place_digit(pid_stable[3:0],  10'd533,10'd173,px,py);
    wire k11= place_digit(last_key1[7:4],    10'd56, 10'd277,px,py);
    wire k10= place_digit(last_key1[3:0],    10'd118,10'd277,px,py);
    wire k21= place_digit(last_key2[7:4],    10'd252,10'd277,px,py);
    wire k20= place_digit(last_key2[3:0],    10'd314,10'd277,px,py);
    wire m1 = place_digit(last_mod[7:4],     10'd447,10'd277,px,py);
    wire m0 = place_digit(last_mod[3:0],     10'd509,10'd277,px,py);
    wire c3 = place_digit(report_count[7:4],10'd167,10'd375,px,py);
    wire c2 = place_digit(report_count[3:0],10'd229,10'd375,px,py);
    wire c1 = place_digit(tx_count[7:4],10'd353,10'd375,px,py);
    wire c0 = place_digit(tx_count[3:0],10'd415,10'd375,px,py);

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
        if (!host_mode) begin
            rgb = 24'h07162C; // background
            // Header and heartbeat: right upper corner changes every 0.5s.
            if (py < 10'd50) rgb = 24'h16406C;
            if (py >= 10'd15 && py < 10'd35 && px >= 10'd40 && px < 10'd500)
                rgb = 24'h23D8EA;
            if (py >= 10'd10 && py < 10'd42 && px >= 10'd565 && px < 10'd615)
                rgb = beat_stable ? 24'h78FF6A : 24'h143E2A;
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
        end else if (game_view) begin
            rgb = console_rgb;
        end else begin
            rgb = 24'h081625;
            if (py < 10'd46) rgb = 24'h153C66;
            if (px >= 10'd26 && px < 10'd504 && py >= 10'd12 && py < 10'd29)
                rgb = 24'h28D5EA;  // video alive header
            if (px >= 10'd564 && px < 10'd612 && py >= 10'd8 && py < 10'd38)
                rgb = beat_stable ? 24'h69E76C : 24'h205638; // USB 60 MHz clock heartbeat
            // TYPE orange and ERR red/green status blocks.
            if (px >= 10'd30 && px < 10'd608 && py >= 10'd52 && py < 10'd153)
                rgb = 24'h123348;
            if (px >= 10'd38 && px < 10'd61 && py >= 10'd83 && py < 10'd122)
                rgb = typ_stable != 0 ? 24'h43D27B : 24'hAC3F4C;
            if (px >= 10'd219 && px < 10'd243 && py >= 10'd83 && py < 10'd122)
                rgb = error_stable ? 24'hE94D53 : 24'h54C774;
            if (px >= 10'd360 && px < 10'd570 && py >= 10'd85 && py < 10'd126)
                rgb = typ_stable == 2'd1 ? 24'h369D54 :
                      typ_stable == 2'd2 ? 24'h247EC5 :
                      typ_stable == 2'd3 ? 24'hC69035 : 24'h273E52;
            if (type_digit || error_digit) rgb = 24'hFAF6EF;
            // HOST activity: yellow when busy, purple when USB D+/D- are actively driven.
            if (px >= 10'd447 && px < 10'd490 && py >= 10'd90 && py < 10'd125)
                rgb = busy_stable ? 24'hF3C55D : 24'h463E2A;
            if (px >= 10'd500 && px < 10'd543 && py >= 10'd90 && py < 10'd125)
                rgb = usb_line_drive ? 24'hD764EE : 24'h44304A;
            // VID (left) / PID (right) cyan/pink.
            if (px >= 10'd30 && px < 10'd310 && py >= 10'd159 && py < 10'd259)
                rgb = 24'h102D43;
            if (px >= 10'd330 && px < 10'd608 && py >= 10'd159 && py < 10'd259)
                rgb = 24'h2E233C;
            if (v3 || v2 || v1 || v0) rgb = 24'h4EE7EB;
            if (p3 || p2 || p1 || p0) rgb = 24'hF3A6EA;
            // USB keyboard HID: key1, key2, modifier.
            if (px >= 10'd30 && px < 10'd214 && py >= 10'd264 && py < 10'd362) rgb = 24'h133A2F;
            if (px >= 10'd230 && px < 10'd407 && py >= 10'd264 && py < 10'd362) rgb = 24'h233A41;
            if (px >= 10'd424 && px < 10'd608 && py >= 10'd264 && py < 10'd362) rgb = 24'h3D3326;
            if (k11 || k10) rgb = 24'h80E49C;
            if (k21 || k20) rgb = 24'h8BDBFB;
            if (m1 || m0) rgb = 24'hFDD582;
            // Lower row: left two hex digits HID reports, right two hex digits USB TX attempts.
            if (px >= 10'd30 && px < 10'd319 && py >= 10'd368 && py < 10'd463) rgb = 24'h1A3F32; // report count
            if (px >= 10'd320 && px < 10'd608 && py >= 10'd368 && py < 10'd463) rgb = 24'h3A273B; // USB TX edge count
            if (c3 || c2) rgb = 24'h9EECBC;
            if (c1 || c0) rgb = 24'hFFC97A;
            if (px >= screen_width || py >= screen_height) rgb = 24'h000000;
        end
        // Mode confirmation visible in both pages.  PASSIVE=blue, HOST=orange.
        if ((!host_mode || !game_view) &&
            px >= 10'd503 && px < 10'd557 && py >= 10'd8 && py < 10'd43)
            rgb = host_mode ? 24'hF7A64A : 24'h206BA5;
    end
    assign red   = w_red'(rgb[23:16]);
    assign green = w_green'(rgb[15:8]);
    assign blue  = w_blue'(rgb[7:0]);
endmodule
