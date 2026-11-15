// PR25-KONSOL-LOCAL-TRIAL
// Original author lab_top port contract; custom local RGB source.
// Static 80x30 KonSol-style demonstration. No actual CP/M/FS or UART commands.
// No modifications to original PMOD pins, DVI_TX, PLL, VGA/DE/HSYNC/VSYNC.
`include "config.svh"

module lab_top
# (
    parameter  clk_mhz       = 50,
               w_key         = 4,
               w_sw          = 8,
               w_led         = 8,
               w_digit       = 8,
               w_gpio        = 100,
               screen_width  = 640,
               screen_height = 480,
               w_red         = 4,
               w_green       = 4,
               w_blue        = 4,
               w_x           = $clog2(screen_width),
               w_y           = $clog2(screen_height)
)
(
    input                       clk,
    input                       slow_clk,
    input                       rst,
    input  [w_key - 1:0]       key,
    input  [w_sw - 1:0]        sw,
    output logic [w_led - 1:0] led,
    output logic [7:0]         abcdefgh,
    output logic [w_digit - 1:0] digit,
    input  [w_x - 1:0]        x,
    input  [w_y - 1:0]        y,
    output logic [w_red - 1:0]   red,
    output logic [w_green - 1:0] green,
    output logic [w_blue - 1:0]  blue,
    input  [23:0]             mic,
    output [15:0]             sound,
    input                      uart_rx,
    output                     uart_tx,
    inout [w_gpio - 1:0]     gpio
);

    assign led = '0;
    assign abcdefgh = '0;
    assign digit = '0;
    assign sound = '0;
    assign uart_tx = 1'b1;
    assign gpio = 'z;

    // Pure combinational glyph ROM, manually authored 5x7 bitmaps.
    function automatic [34:0] glyph(input logic [7:0] ch);
        begin
            case (ch)
                8'h20: glyph = 35'b00000_00000_00000_00000_00000_00000_00000; // ' '
                8'h21: glyph = 35'b00100_00100_00100_00100_00100_00000_00100; // '!'
                8'h23: glyph = 35'b01010_01010_11111_01010_11111_01010_01010; // '#'
                8'h25: glyph = 35'b11001_11010_00100_01000_10110_00110_00000; // '%'
                8'h27: glyph = 35'b00100_00100_00000_00000_00000_00000_00000; // "'"
                8'h28: glyph = 35'b00110_01000_10000_10000_10000_01000_00110; // '('
                8'h29: glyph = 35'b01100_00010_00001_00001_00001_00010_01100; // ')'
                8'h2A: glyph = 35'b00000_10101_01110_11111_01110_10101_00000; // '*'
                8'h2B: glyph = 35'b00000_00100_00100_11111_00100_00100_00000; // '+'
                8'h2C: glyph = 35'b00000_00000_00000_00000_00110_00110_00100; // ','
                8'h2D: glyph = 35'b00000_00000_00000_11111_00000_00000_00000; // '-'
                8'h2E: glyph = 35'b00000_00000_00000_00000_00000_01100_01100; // '.'
                8'h2F: glyph = 35'b00001_00001_00010_00100_01000_10000_10000; // '/'
                8'h30: glyph = 35'b01110_10001_10011_10101_11001_10001_01110; // '0'
                8'h31: glyph = 35'b00100_01100_00100_00100_00100_00100_01110; // '1'
                8'h32: glyph = 35'b01110_10001_00001_00010_00100_01000_11111; // '2'
                8'h33: glyph = 35'b11110_00001_00001_01110_00001_00001_11110; // '3'
                8'h34: glyph = 35'b00010_00110_01010_10010_11111_00010_00010; // '4'
                8'h35: glyph = 35'b11111_10000_10000_11110_00001_00001_11110; // '5'
                8'h36: glyph = 35'b01111_10000_10000_11110_10001_10001_01110; // '6'
                8'h37: glyph = 35'b11111_00001_00010_00100_01000_01000_01000; // '7'
                8'h38: glyph = 35'b01110_10001_10001_01110_10001_10001_01110; // '8'
                8'h39: glyph = 35'b01110_10001_10001_01111_00001_00001_11110; // '9'
                8'h3A: glyph = 35'b00000_01100_01100_00000_01100_01100_00000; // ':'
                8'h3B: glyph = 35'b00000_00110_00110_00000_00110_00100_01000; // ';'
                8'h3C: glyph = 35'b00001_00010_00100_01000_00100_00010_00001; // '<'
                8'h3D: glyph = 35'b00000_00000_11111_00000_11111_00000_00000; // '='
                8'h3E: glyph = 35'b10000_01000_00100_00010_00100_01000_10000; // '>'
                8'h3F: glyph = 35'b01110_10001_00001_00010_00100_00000_00100; // '?'
                8'h40: glyph = 35'b01110_10001_10111_10101_10111_10000_01111; // '@'
                8'h41: glyph = 35'b01110_10001_10001_11111_10001_10001_10001; // 'A'
                8'h42: glyph = 35'b11110_10001_10001_11110_10001_10001_11110; // 'B'
                8'h43: glyph = 35'b01111_10000_10000_10000_10000_10000_01111; // 'C'
                8'h44: glyph = 35'b11110_10001_10001_10001_10001_10001_11110; // 'D'
                8'h45: glyph = 35'b11111_10000_10000_11110_10000_10000_11111; // 'E'
                8'h46: glyph = 35'b11111_10000_10000_11110_10000_10000_10000; // 'F'
                8'h47: glyph = 35'b01111_10000_10000_10111_10001_10001_01111; // 'G'
                8'h48: glyph = 35'b10001_10001_10001_11111_10001_10001_10001; // 'H'
                8'h49: glyph = 35'b01110_00100_00100_00100_00100_00100_01110; // 'I'
                8'h4A: glyph = 35'b00111_00010_00010_00010_10010_10010_01100; // 'J'
                8'h4B: glyph = 35'b10001_10010_10100_11000_10100_10010_10001; // 'K'
                8'h4C: glyph = 35'b10000_10000_10000_10000_10000_10000_11111; // 'L'
                8'h4D: glyph = 35'b10001_11011_10101_10101_10001_10001_10001; // 'M'
                8'h4E: glyph = 35'b10001_11001_10101_10011_10001_10001_10001; // 'N'
                8'h4F: glyph = 35'b01110_10001_10001_10001_10001_10001_01110; // 'O'
                8'h50: glyph = 35'b11110_10001_10001_11110_10000_10000_10000; // 'P'
                8'h51: glyph = 35'b01110_10001_10001_10001_10101_10010_01101; // 'Q'
                8'h52: glyph = 35'b11110_10001_10001_11110_10100_10010_10001; // 'R'
                8'h53: glyph = 35'b01111_10000_10000_01110_00001_00001_11110; // 'S'
                8'h54: glyph = 35'b11111_00100_00100_00100_00100_00100_00100; // 'T'
                8'h55: glyph = 35'b10001_10001_10001_10001_10001_10001_01110; // 'U'
                8'h56: glyph = 35'b10001_10001_10001_10001_10001_01010_00100; // 'V'
                8'h57: glyph = 35'b10001_10001_10001_10101_10101_10101_01010; // 'W'
                8'h58: glyph = 35'b10001_10001_01010_00100_01010_10001_10001; // 'X'
                8'h59: glyph = 35'b10001_10001_01010_00100_00100_00100_00100; // 'Y'
                8'h5A: glyph = 35'b11111_00001_00010_00100_01000_10000_11111; // 'Z'
                8'h5B: glyph = 35'b01110_01000_01000_01000_01000_01000_01110; // '['
                8'h5C: glyph = 35'b10000_10000_01000_00100_00010_00001_00001; // '\\'
                8'h5D: glyph = 35'b01110_00010_00010_00010_00010_00010_01110; // ']'
                8'h5F: glyph = 35'b00000_00000_00000_00000_00000_00000_11111; // '_'
                8'h7C: glyph = 35'b00100_00100_00100_00100_00100_00100_00100; // '|'
                default: glyph = 35'd0;
            endcase
        end
    endfunction

    function automatic [4:0] glyph_row(input logic [34:0] g, input logic [2:0] gy);
        begin
            case (gy)
                3'd0: glyph_row = g[34:30];
                3'd1: glyph_row = g[29:25];
                3'd2: glyph_row = g[24:20];
                3'd3: glyph_row = g[19:15];
                3'd4: glyph_row = g[14:10];
                3'd5: glyph_row = g[9:5];
                3'd6: glyph_row = g[4:0];
                default: glyph_row = 5'd0;
            endcase
        end
    endfunction

    function automatic [7:0] screen_char(input logic [11:0] addr);
        begin
            case (addr)
                12'd2: screen_char = 8'h4B;
                12'd3: screen_char = 8'h4F;
                12'd4: screen_char = 8'h4E;
                12'd5: screen_char = 8'h53;
                12'd6: screen_char = 8'h4F;
                12'd7: screen_char = 8'h4C;
                12'd9: screen_char = 8'h43;
                12'd10: screen_char = 8'h4F;
                12'd11: screen_char = 8'h4D;
                12'd12: screen_char = 8'h4D;
                12'd13: screen_char = 8'h41;
                12'd14: screen_char = 8'h4E;
                12'd15: screen_char = 8'h44;
                12'd16: screen_char = 8'h45;
                12'd17: screen_char = 8'h52;
                12'd19: screen_char = 8'h32;
                12'd20: screen_char = 8'h35;
                12'd21: screen_char = 8'h4B;
                12'd29: screen_char = 8'h54;
                12'd30: screen_char = 8'h41;
                12'd31: screen_char = 8'h4E;
                12'd32: screen_char = 8'h47;
                12'd34: screen_char = 8'h50;
                12'd35: screen_char = 8'h52;
                12'd36: screen_char = 8'h49;
                12'd37: screen_char = 8'h4D;
                12'd38: screen_char = 8'h45;
                12'd39: screen_char = 8'h52;
                12'd41: screen_char = 8'h32;
                12'd42: screen_char = 8'h35;
                12'd43: screen_char = 8'h4B;
                12'd46: screen_char = 8'h2F;
                12'd49: screen_char = 8'h44;
                12'd50: screen_char = 8'h56;
                12'd51: screen_char = 8'h49;
                12'd53: screen_char = 8'h36;
                12'd54: screen_char = 8'h34;
                12'd55: screen_char = 8'h30;
                12'd56: screen_char = 8'h58;
                12'd57: screen_char = 8'h34;
                12'd58: screen_char = 8'h38;
                12'd59: screen_char = 8'h30;
                12'd259: screen_char = 8'h4B;
                12'd260: screen_char = 8'h4F;
                12'd261: screen_char = 8'h4E;
                12'd262: screen_char = 8'h53;
                12'd263: screen_char = 8'h4F;
                12'd264: screen_char = 8'h4C;
                12'd266: screen_char = 8'h2F;
                12'd267: screen_char = 8'h2F;
                12'd269: screen_char = 8'h46;
                12'd270: screen_char = 8'h50;
                12'd271: screen_char = 8'h47;
                12'd272: screen_char = 8'h41;
                12'd274: screen_char = 8'h43;
                12'd275: screen_char = 8'h4F;
                12'd276: screen_char = 8'h4E;
                12'd277: screen_char = 8'h53;
                12'd278: screen_char = 8'h4F;
                12'd279: screen_char = 8'h4C;
                12'd280: screen_char = 8'h45;
                12'd282: screen_char = 8'h2F;
                12'd283: screen_char = 8'h2F;
                12'd285: screen_char = 8'h4D;
                12'd286: screen_char = 8'h55;
                12'd287: screen_char = 8'h4C;
                12'd288: screen_char = 8'h54;
                12'd289: screen_char = 8'h49;
                12'd290: screen_char = 8'h43;
                12'd291: screen_char = 8'h4F;
                12'd292: screen_char = 8'h4C;
                12'd293: screen_char = 8'h4F;
                12'd294: screen_char = 8'h52;
                12'd296: screen_char = 8'h56;
                12'd297: screen_char = 8'h49;
                12'd298: screen_char = 8'h44;
                12'd299: screen_char = 8'h45;
                12'd300: screen_char = 8'h4F;
                12'd302: screen_char = 8'h54;
                12'd303: screen_char = 8'h45;
                12'd304: screen_char = 8'h53;
                12'd305: screen_char = 8'h54;
                12'd387: screen_char = 8'h47;
                12'd388: screen_char = 8'h4F;
                12'd389: screen_char = 8'h57;
                12'd390: screen_char = 8'h49;
                12'd391: screen_char = 8'h4E;
                12'd393: screen_char = 8'h44;
                12'd394: screen_char = 8'h56;
                12'd395: screen_char = 8'h49;
                12'd397: screen_char = 8'h54;
                12'd398: screen_char = 8'h58;
                12'd401: screen_char = 8'h7C;
                12'd404: screen_char = 8'h52;
                12'd405: screen_char = 8'h47;
                12'd406: screen_char = 8'h42;
                12'd407: screen_char = 8'h38;
                12'd408: screen_char = 8'h38;
                12'd409: screen_char = 8'h38;
                12'd412: screen_char = 8'h7C;
                12'd415: screen_char = 8'h38;
                12'd416: screen_char = 8'h30;
                12'd418: screen_char = 8'h58;
                12'd420: screen_char = 8'h33;
                12'd421: screen_char = 8'h30;
                12'd423: screen_char = 8'h43;
                12'd424: screen_char = 8'h45;
                12'd425: screen_char = 8'h4C;
                12'd426: screen_char = 8'h4C;
                12'd427: screen_char = 8'h53;
                12'd430: screen_char = 8'h7C;
                12'd433: screen_char = 8'h4E;
                12'd434: screen_char = 8'h4F;
                12'd436: screen_char = 8'h53;
                12'd437: screen_char = 8'h44;
                12'd438: screen_char = 8'h52;
                12'd439: screen_char = 8'h41;
                12'd440: screen_char = 8'h4D;
                12'd643: screen_char = 8'h4C;
                12'd644: screen_char = 8'h45;
                12'd645: screen_char = 8'h46;
                12'd646: screen_char = 8'h54;
                12'd648: screen_char = 8'h50;
                12'd649: screen_char = 8'h41;
                12'd650: screen_char = 8'h4E;
                12'd651: screen_char = 8'h45;
                12'd652: screen_char = 8'h4C;
                12'd655: screen_char = 8'h41;
                12'd656: screen_char = 8'h3A;
                12'd683: screen_char = 8'h52;
                12'd684: screen_char = 8'h49;
                12'd685: screen_char = 8'h47;
                12'd686: screen_char = 8'h48;
                12'd687: screen_char = 8'h54;
                12'd689: screen_char = 8'h50;
                12'd690: screen_char = 8'h41;
                12'd691: screen_char = 8'h4E;
                12'd692: screen_char = 8'h45;
                12'd693: screen_char = 8'h4C;
                12'd696: screen_char = 8'h42;
                12'd697: screen_char = 8'h3A;
                12'd899: screen_char = 8'h3E;
                12'd901: screen_char = 8'h52;
                12'd902: screen_char = 8'h45;
                12'd903: screen_char = 8'h41;
                12'd904: screen_char = 8'h44;
                12'd905: screen_char = 8'h4D;
                12'd906: screen_char = 8'h45;
                12'd909: screen_char = 8'h2E;
                12'd910: screen_char = 8'h54;
                12'd911: screen_char = 8'h58;
                12'd912: screen_char = 8'h54;
                12'd920: screen_char = 8'h32;
                12'd922: screen_char = 8'h4B;
                12'd923: screen_char = 8'h42;
                12'd941: screen_char = 8'h56;
                12'd942: screen_char = 8'h49;
                12'd943: screen_char = 8'h44;
                12'd944: screen_char = 8'h45;
                12'd945: screen_char = 8'h4F;
                12'd949: screen_char = 8'h2E;
                12'd950: screen_char = 8'h53;
                12'd951: screen_char = 8'h59;
                12'd952: screen_char = 8'h53;
                12'd958: screen_char = 8'h36;
                12'd959: screen_char = 8'h34;
                12'd960: screen_char = 8'h30;
                12'd962: screen_char = 8'h58;
                12'd964: screen_char = 8'h34;
                12'd965: screen_char = 8'h38;
                12'd966: screen_char = 8'h30;
                12'd1029: screen_char = 8'h44;
                12'd1030: screen_char = 8'h55;
                12'd1031: screen_char = 8'h4D;
                12'd1032: screen_char = 8'h50;
                12'd1037: screen_char = 8'h2E;
                12'd1038: screen_char = 8'h43;
                12'd1039: screen_char = 8'h4F;
                12'd1040: screen_char = 8'h4D;
                12'd1048: screen_char = 8'h38;
                12'd1050: screen_char = 8'h4B;
                12'd1051: screen_char = 8'h42;
                12'd1069: screen_char = 8'h54;
                12'd1070: screen_char = 8'h4D;
                12'd1071: screen_char = 8'h44;
                12'd1072: screen_char = 8'h53;
                12'd1077: screen_char = 8'h2E;
                12'd1078: screen_char = 8'h49;
                12'd1079: screen_char = 8'h50;
                12'd1086: screen_char = 8'h47;
                12'd1087: screen_char = 8'h4F;
                12'd1088: screen_char = 8'h57;
                12'd1089: screen_char = 8'h49;
                12'd1090: screen_char = 8'h4E;
                12'd1092: screen_char = 8'h44;
                12'd1093: screen_char = 8'h56;
                12'd1094: screen_char = 8'h49;
                12'd1157: screen_char = 8'h53;
                12'd1158: screen_char = 8'h54;
                12'd1159: screen_char = 8'h41;
                12'd1160: screen_char = 8'h54;
                12'd1165: screen_char = 8'h2E;
                12'd1166: screen_char = 8'h43;
                12'd1167: screen_char = 8'h4F;
                12'd1168: screen_char = 8'h4D;
                12'd1176: screen_char = 8'h34;
                12'd1178: screen_char = 8'h4B;
                12'd1179: screen_char = 8'h42;
                12'd1197: screen_char = 8'h53;
                12'd1198: screen_char = 8'h43;
                12'd1199: screen_char = 8'h52;
                12'd1200: screen_char = 8'h45;
                12'd1201: screen_char = 8'h45;
                12'd1202: screen_char = 8'h4E;
                12'd1205: screen_char = 8'h2E;
                12'd1206: screen_char = 8'h52;
                12'd1207: screen_char = 8'h47;
                12'd1208: screen_char = 8'h42;
                12'd1214: screen_char = 8'h32;
                12'd1215: screen_char = 8'h34;
                12'd1217: screen_char = 8'h42;
                12'd1218: screen_char = 8'h49;
                12'd1219: screen_char = 8'h54;
                12'd1285: screen_char = 8'h41;
                12'd1286: screen_char = 8'h53;
                12'd1287: screen_char = 8'h4D;
                12'd1293: screen_char = 8'h2E;
                12'd1294: screen_char = 8'h43;
                12'd1295: screen_char = 8'h4F;
                12'd1296: screen_char = 8'h4D;
                12'd1303: screen_char = 8'h31;
                12'd1304: screen_char = 8'h32;
                12'd1306: screen_char = 8'h4B;
                12'd1307: screen_char = 8'h42;
                12'd1325: screen_char = 8'h46;
                12'd1326: screen_char = 8'h4F;
                12'd1327: screen_char = 8'h4E;
                12'd1328: screen_char = 8'h54;
                12'd1333: screen_char = 8'h2E;
                12'd1334: screen_char = 8'h52;
                12'd1335: screen_char = 8'h4F;
                12'd1336: screen_char = 8'h4D;
                12'd1342: screen_char = 8'h35;
                12'd1344: screen_char = 8'h58;
                12'd1346: screen_char = 8'h37;
                12'd1413: screen_char = 8'h43;
                12'd1414: screen_char = 8'h4F;
                12'd1415: screen_char = 8'h50;
                12'd1416: screen_char = 8'h59;
                12'd1421: screen_char = 8'h2E;
                12'd1422: screen_char = 8'h43;
                12'd1423: screen_char = 8'h4F;
                12'd1424: screen_char = 8'h4D;
                12'd1432: screen_char = 8'h36;
                12'd1434: screen_char = 8'h4B;
                12'd1435: screen_char = 8'h42;
                12'd1453: screen_char = 8'h42;
                12'd1454: screen_char = 8'h52;
                12'd1455: screen_char = 8'h41;
                12'd1456: screen_char = 8'h4D;
                12'd1461: screen_char = 8'h2E;
                12'd1462: screen_char = 8'h43;
                12'd1463: screen_char = 8'h46;
                12'd1464: screen_char = 8'h47;
                12'd1470: screen_char = 8'h4E;
                12'd1471: screen_char = 8'h4F;
                12'd1472: screen_char = 8'h54;
                12'd1474: screen_char = 8'h55;
                12'd1475: screen_char = 8'h53;
                12'd1476: screen_char = 8'h45;
                12'd1477: screen_char = 8'h44;
                12'd1541: screen_char = 8'h53;
                12'd1542: screen_char = 8'h4F;
                12'd1543: screen_char = 8'h52;
                12'd1544: screen_char = 8'h54;
                12'd1549: screen_char = 8'h2E;
                12'd1550: screen_char = 8'h42;
                12'd1551: screen_char = 8'h42;
                12'd1552: screen_char = 8'h43;
                12'd1560: screen_char = 8'h33;
                12'd1562: screen_char = 8'h4B;
                12'd1563: screen_char = 8'h42;
                12'd1581: screen_char = 8'h55;
                12'd1582: screen_char = 8'h41;
                12'd1583: screen_char = 8'h52;
                12'd1584: screen_char = 8'h54;
                12'd1589: screen_char = 8'h2E;
                12'd1590: screen_char = 8'h43;
                12'd1591: screen_char = 8'h46;
                12'd1592: screen_char = 8'h47;
                12'd1598: screen_char = 8'h49;
                12'd1599: screen_char = 8'h44;
                12'd1600: screen_char = 8'h4C;
                12'd1601: screen_char = 8'h45;
                12'd1669: screen_char = 8'h4B;
                12'd1670: screen_char = 8'h58;
                12'd1671: screen_char = 8'h46;
                12'd1672: screen_char = 8'h45;
                12'd1673: screen_char = 8'h52;
                12'd1677: screen_char = 8'h2E;
                12'd1678: screen_char = 8'h42;
                12'd1679: screen_char = 8'h42;
                12'd1680: screen_char = 8'h43;
                12'd1688: screen_char = 8'h34;
                12'd1690: screen_char = 8'h4B;
                12'd1691: screen_char = 8'h42;
                12'd1709: screen_char = 8'h48;
                12'd1710: screen_char = 8'h44;
                12'd1711: screen_char = 8'h4D;
                12'd1712: screen_char = 8'h49;
                12'd1717: screen_char = 8'h2E;
                12'd1718: screen_char = 8'h54;
                12'd1719: screen_char = 8'h58;
                12'd1720: screen_char = 8'h54;
                12'd1726: screen_char = 8'h56;
                12'd1727: screen_char = 8'h49;
                12'd1728: screen_char = 8'h44;
                12'd1729: screen_char = 8'h45;
                12'd1730: screen_char = 8'h4F;
                12'd1732: screen_char = 8'h4F;
                12'd1733: screen_char = 8'h4E;
                12'd1734: screen_char = 8'h4C;
                12'd1735: screen_char = 8'h59;
                12'd1797: screen_char = 8'h4B;
                12'd1798: screen_char = 8'h58;
                12'd1799: screen_char = 8'h32;
                12'd1800: screen_char = 8'h46;
                12'd1801: screen_char = 8'h45;
                12'd1802: screen_char = 8'h52;
                12'd1805: screen_char = 8'h2E;
                12'd1806: screen_char = 8'h42;
                12'd1807: screen_char = 8'h42;
                12'd1808: screen_char = 8'h43;
                12'd1816: screen_char = 8'h35;
                12'd1818: screen_char = 8'h4B;
                12'd1819: screen_char = 8'h42;
                12'd1837: screen_char = 8'h50;
                12'd1838: screen_char = 8'h4D;
                12'd1839: screen_char = 8'h4F;
                12'd1840: screen_char = 8'h44;
                12'd1845: screen_char = 8'h2E;
                12'd1846: screen_char = 8'h54;
                12'd1847: screen_char = 8'h58;
                12'd1848: screen_char = 8'h54;
                12'd1854: screen_char = 8'h53;
                12'd1855: screen_char = 8'h41;
                12'd1856: screen_char = 8'h4D;
                12'd1857: screen_char = 8'h45;
                12'd1859: screen_char = 8'h50;
                12'd1860: screen_char = 8'h49;
                12'd1861: screen_char = 8'h4E;
                12'd1862: screen_char = 8'h53;
                12'd1925: screen_char = 8'h42;
                12'd1926: screen_char = 8'h41;
                12'd1927: screen_char = 8'h53;
                12'd1928: screen_char = 8'h49;
                12'd1929: screen_char = 8'h43;
                12'd1933: screen_char = 8'h2E;
                12'd1934: screen_char = 8'h43;
                12'd1935: screen_char = 8'h4F;
                12'd1936: screen_char = 8'h4D;
                12'd1943: screen_char = 8'h31;
                12'd1944: screen_char = 8'h36;
                12'd1946: screen_char = 8'h4B;
                12'd1947: screen_char = 8'h42;
                12'd1965: screen_char = 8'h42;
                12'd1966: screen_char = 8'h55;
                12'd1967: screen_char = 8'h49;
                12'd1968: screen_char = 8'h4C;
                12'd1969: screen_char = 8'h44;
                12'd1973: screen_char = 8'h2E;
                12'd1974: screen_char = 8'h4C;
                12'd1975: screen_char = 8'h4F;
                12'd1976: screen_char = 8'h47;
                12'd1982: screen_char = 8'h4E;
                12'd1983: screen_char = 8'h45;
                12'd1984: screen_char = 8'h57;
                12'd1986: screen_char = 8'h54;
                12'd1987: screen_char = 8'h52;
                12'd1988: screen_char = 8'h49;
                12'd1989: screen_char = 8'h41;
                12'd1990: screen_char = 8'h4C;
                12'd2181: screen_char = 8'h39;
                12'd2183: screen_char = 8'h46;
                12'd2184: screen_char = 8'h49;
                12'd2185: screen_char = 8'h4C;
                12'd2186: screen_char = 8'h45;
                12'd2187: screen_char = 8'h53;
                12'd2194: screen_char = 8'h36;
                12'd2195: screen_char = 8'h30;
                12'd2197: screen_char = 8'h4B;
                12'd2198: screen_char = 8'h42;
                12'd2200: screen_char = 8'h46;
                12'd2201: screen_char = 8'h52;
                12'd2202: screen_char = 8'h45;
                12'd2203: screen_char = 8'h45;
                12'd2221: screen_char = 8'h52;
                12'd2222: screen_char = 8'h45;
                12'd2223: screen_char = 8'h41;
                12'd2224: screen_char = 8'h44;
                12'd2225: screen_char = 8'h59;
                12'd2228: screen_char = 8'h2F;
                12'd2231: screen_char = 8'h4E;
                12'd2232: screen_char = 8'h4F;
                12'd2234: screen_char = 8'h53;
                12'd2235: screen_char = 8'h54;
                12'd2236: screen_char = 8'h4F;
                12'd2237: screen_char = 8'h52;
                12'd2238: screen_char = 8'h41;
                12'd2239: screen_char = 8'h47;
                12'd2240: screen_char = 8'h45;
                12'd2437: screen_char = 8'h44;
                12'd2438: screen_char = 8'h49;
                12'd2439: screen_char = 8'h52;
                12'd2440: screen_char = 8'h45;
                12'd2441: screen_char = 8'h43;
                12'd2442: screen_char = 8'h54;
                12'd2443: screen_char = 8'h4F;
                12'd2444: screen_char = 8'h52;
                12'd2445: screen_char = 8'h59;
                12'd2446: screen_char = 8'h3A;
                12'd2448: screen_char = 8'h53;
                12'd2449: screen_char = 8'h54;
                12'd2450: screen_char = 8'h41;
                12'd2451: screen_char = 8'h54;
                12'd2452: screen_char = 8'h49;
                12'd2453: screen_char = 8'h43;
                12'd2455: screen_char = 8'h44;
                12'd2456: screen_char = 8'h45;
                12'd2457: screen_char = 8'h4D;
                12'd2458: screen_char = 8'h4F;
                12'd2477: screen_char = 8'h46;
                12'd2478: screen_char = 8'h50;
                12'd2479: screen_char = 8'h47;
                12'd2480: screen_char = 8'h41;
                12'd2482: screen_char = 8'h47;
                12'd2483: screen_char = 8'h45;
                12'd2484: screen_char = 8'h4E;
                12'd2485: screen_char = 8'h45;
                12'd2486: screen_char = 8'h52;
                12'd2487: screen_char = 8'h41;
                12'd2488: screen_char = 8'h54;
                12'd2489: screen_char = 8'h45;
                12'd2490: screen_char = 8'h44;
                12'd2492: screen_char = 8'h50;
                12'd2493: screen_char = 8'h49;
                12'd2494: screen_char = 8'h58;
                12'd2495: screen_char = 8'h45;
                12'd2496: screen_char = 8'h4C;
                12'd2497: screen_char = 8'h53;
                12'd2693: screen_char = 8'h43;
                12'd2694: screen_char = 8'h4F;
                12'd2695: screen_char = 8'h4C;
                12'd2696: screen_char = 8'h4F;
                12'd2697: screen_char = 8'h52;
                12'd2701: screen_char = 8'h43;
                12'd2702: screen_char = 8'h59;
                12'd2703: screen_char = 8'h41;
                12'd2704: screen_char = 8'h4E;
                12'd2706: screen_char = 8'h4D;
                12'd2707: screen_char = 8'h41;
                12'd2708: screen_char = 8'h47;
                12'd2709: screen_char = 8'h45;
                12'd2710: screen_char = 8'h4E;
                12'd2711: screen_char = 8'h54;
                12'd2712: screen_char = 8'h41;
                12'd2714: screen_char = 8'h59;
                12'd2715: screen_char = 8'h45;
                12'd2716: screen_char = 8'h4C;
                12'd2717: screen_char = 8'h4C;
                12'd2718: screen_char = 8'h4F;
                12'd2719: screen_char = 8'h57;
                12'd2733: screen_char = 8'h50;
                12'd2734: screen_char = 8'h49;
                12'd2735: screen_char = 8'h58;
                12'd2736: screen_char = 8'h45;
                12'd2737: screen_char = 8'h4C;
                12'd2739: screen_char = 8'h4F;
                12'd2740: screen_char = 8'h55;
                12'd2741: screen_char = 8'h54;
                12'd2742: screen_char = 8'h50;
                12'd2743: screen_char = 8'h55;
                12'd2744: screen_char = 8'h54;
                12'd2745: screen_char = 8'h3A;
                12'd2747: screen_char = 8'h52;
                12'd2748: screen_char = 8'h47;
                12'd2749: screen_char = 8'h42;
                12'd2750: screen_char = 8'h38;
                12'd2751: screen_char = 8'h38;
                12'd2752: screen_char = 8'h38;
                12'd2947: screen_char = 8'h4B;
                12'd2948: screen_char = 8'h4F;
                12'd2949: screen_char = 8'h4E;
                12'd2950: screen_char = 8'h53;
                12'd2951: screen_char = 8'h4F;
                12'd2952: screen_char = 8'h4C;
                12'd2953: screen_char = 8'h3E;
                12'd2955: screen_char = 8'h44;
                12'd2956: screen_char = 8'h49;
                12'd2957: screen_char = 8'h52;
                12'd2959: screen_char = 8'h41;
                12'd2960: screen_char = 8'h3A;
                12'd2987: screen_char = 8'h4B;
                12'd2988: screen_char = 8'h4F;
                12'd2989: screen_char = 8'h4E;
                12'd2990: screen_char = 8'h53;
                12'd2991: screen_char = 8'h4F;
                12'd2992: screen_char = 8'h4C;
                12'd2993: screen_char = 8'h3E;
                12'd2995: screen_char = 8'h54;
                12'd2996: screen_char = 8'h45;
                12'd2997: screen_char = 8'h53;
                12'd2998: screen_char = 8'h54;
                12'd3000: screen_char = 8'h56;
                12'd3001: screen_char = 8'h49;
                12'd3002: screen_char = 8'h44;
                12'd3003: screen_char = 8'h45;
                12'd3004: screen_char = 8'h4F;
                12'd3203: screen_char = 8'h56;
                12'd3204: screen_char = 8'h49;
                12'd3205: screen_char = 8'h44;
                12'd3206: screen_char = 8'h45;
                12'd3207: screen_char = 8'h4F;
                12'd3209: screen_char = 8'h4F;
                12'd3210: screen_char = 8'h4E;
                12'd3211: screen_char = 8'h4C;
                12'd3212: screen_char = 8'h59;
                12'd3215: screen_char = 8'h2F;
                12'd3218: screen_char = 8'h4E;
                12'd3219: screen_char = 8'h4F;
                12'd3221: screen_char = 8'h4B;
                12'd3222: screen_char = 8'h45;
                12'd3223: screen_char = 8'h59;
                12'd3224: screen_char = 8'h42;
                12'd3225: screen_char = 8'h4F;
                12'd3226: screen_char = 8'h41;
                12'd3227: screen_char = 8'h52;
                12'd3228: screen_char = 8'h44;
                12'd3231: screen_char = 8'h2F;
                12'd3234: screen_char = 8'h4E;
                12'd3235: screen_char = 8'h4F;
                12'd3237: screen_char = 8'h46;
                12'd3238: screen_char = 8'h49;
                12'd3239: screen_char = 8'h4C;
                12'd3240: screen_char = 8'h45;
                12'd3242: screen_char = 8'h53;
                12'd3243: screen_char = 8'h59;
                12'd3244: screen_char = 8'h53;
                12'd3245: screen_char = 8'h54;
                12'd3246: screen_char = 8'h45;
                12'd3247: screen_char = 8'h4D;
                12'd3250: screen_char = 8'h2F;
                12'd3253: screen_char = 8'h44;
                12'd3254: screen_char = 8'h45;
                12'd3255: screen_char = 8'h4D;
                12'd3256: screen_char = 8'h4F;
                12'd3258: screen_char = 8'h53;
                12'd3259: screen_char = 8'h43;
                12'd3260: screen_char = 8'h52;
                12'd3261: screen_char = 8'h45;
                12'd3262: screen_char = 8'h45;
                12'd3263: screen_char = 8'h4E;
                12'd3331: screen_char = 8'h44;
                12'd3332: screen_char = 8'h41;
                12'd3333: screen_char = 8'h54;
                12'd3334: screen_char = 8'h41;
                12'd3335: screen_char = 8'h3A;
                12'd3337: screen_char = 8'h52;
                12'd3338: screen_char = 8'h47;
                12'd3339: screen_char = 8'h42;
                12'd3341: screen_char = 8'h46;
                12'd3342: screen_char = 8'h52;
                12'd3343: screen_char = 8'h4F;
                12'd3344: screen_char = 8'h4D;
                12'd3346: screen_char = 8'h4F;
                12'd3347: screen_char = 8'h55;
                12'd3348: screen_char = 8'h52;
                12'd3350: screen_char = 8'h52;
                12'd3351: screen_char = 8'h54;
                12'd3352: screen_char = 8'h4C;
                12'd3355: screen_char = 8'h7C;
                12'd3358: screen_char = 8'h44;
                12'd3359: screen_char = 8'h56;
                12'd3360: screen_char = 8'h49;
                12'd3362: screen_char = 8'h54;
                12'd3363: screen_char = 8'h58;
                12'd3364: screen_char = 8'h3A;
                12'd3366: screen_char = 8'h4F;
                12'd3367: screen_char = 8'h52;
                12'd3368: screen_char = 8'h49;
                12'd3369: screen_char = 8'h47;
                12'd3370: screen_char = 8'h49;
                12'd3371: screen_char = 8'h4E;
                12'd3372: screen_char = 8'h41;
                12'd3373: screen_char = 8'h4C;
                12'd3375: screen_char = 8'h47;
                12'd3376: screen_char = 8'h4F;
                12'd3377: screen_char = 8'h57;
                12'd3378: screen_char = 8'h49;
                12'd3379: screen_char = 8'h4E;
                12'd3381: screen_char = 8'h49;
                12'd3382: screen_char = 8'h50;
                12'd3459: screen_char = 8'h4C;
                12'd3460: screen_char = 8'h45;
                12'd3461: screen_char = 8'h46;
                12'd3462: screen_char = 8'h54;
                12'd3464: screen_char = 8'h55;
                12'd3465: screen_char = 8'h53;
                12'd3466: screen_char = 8'h42;
                12'd3467: screen_char = 8'h2D;
                12'd3468: screen_char = 8'h41;
                12'd3470: screen_char = 8'h50;
                12'd3471: screen_char = 8'h4D;
                12'd3472: screen_char = 8'h4F;
                12'd3473: screen_char = 8'h44;
                12'd3474: screen_char = 8'h3A;
                12'd3476: screen_char = 8'h56;
                12'd3477: screen_char = 8'h45;
                12'd3478: screen_char = 8'h52;
                12'd3479: screen_char = 8'h49;
                12'd3480: screen_char = 8'h46;
                12'd3481: screen_char = 8'h49;
                12'd3482: screen_char = 8'h45;
                12'd3483: screen_char = 8'h44;
                12'd3486: screen_char = 8'h7C;
                12'd3489: screen_char = 8'h50;
                12'd3490: screen_char = 8'h49;
                12'd3491: screen_char = 8'h4E;
                12'd3492: screen_char = 8'h53;
                12'd3494: screen_char = 8'h2F;
                12'd3496: screen_char = 8'h50;
                12'd3497: screen_char = 8'h4C;
                12'd3498: screen_char = 8'h4C;
                12'd3500: screen_char = 8'h2F;
                12'd3502: screen_char = 8'h53;
                12'd3503: screen_char = 8'h59;
                12'd3504: screen_char = 8'h4E;
                12'd3505: screen_char = 8'h43;
                12'd3506: screen_char = 8'h3A;
                12'd3508: screen_char = 8'h55;
                12'd3509: screen_char = 8'h4E;
                12'd3510: screen_char = 8'h43;
                12'd3511: screen_char = 8'h48;
                12'd3512: screen_char = 8'h41;
                12'd3513: screen_char = 8'h4E;
                12'd3514: screen_char = 8'h47;
                12'd3515: screen_char = 8'h45;
                12'd3516: screen_char = 8'h44;
                12'd3714: screen_char = 8'h46;
                12'd3715: screen_char = 8'h31;
                12'd3717: screen_char = 8'h48;
                12'd3718: screen_char = 8'h45;
                12'd3719: screen_char = 8'h4C;
                12'd3720: screen_char = 8'h50;
                12'd3725: screen_char = 8'h46;
                12'd3726: screen_char = 8'h32;
                12'd3728: screen_char = 8'h43;
                12'd3729: screen_char = 8'h4F;
                12'd3730: screen_char = 8'h50;
                12'd3731: screen_char = 8'h59;
                12'd3736: screen_char = 8'h46;
                12'd3737: screen_char = 8'h33;
                12'd3739: screen_char = 8'h56;
                12'd3740: screen_char = 8'h49;
                12'd3741: screen_char = 8'h45;
                12'd3742: screen_char = 8'h57;
                12'd3747: screen_char = 8'h46;
                12'd3748: screen_char = 8'h34;
                12'd3750: screen_char = 8'h45;
                12'd3751: screen_char = 8'h44;
                12'd3752: screen_char = 8'h49;
                12'd3753: screen_char = 8'h54;
                12'd3758: screen_char = 8'h46;
                12'd3759: screen_char = 8'h35;
                12'd3761: screen_char = 8'h54;
                12'd3762: screen_char = 8'h45;
                12'd3763: screen_char = 8'h53;
                12'd3764: screen_char = 8'h54;
                12'd3768: screen_char = 8'h46;
                12'd3769: screen_char = 8'h31;
                12'd3770: screen_char = 8'h30;
                12'd3772: screen_char = 8'h45;
                12'd3773: screen_char = 8'h58;
                12'd3774: screen_char = 8'h49;
                12'd3775: screen_char = 8'h54;
                12'd3778: screen_char = 8'h5B;
                12'd3779: screen_char = 8'h44;
                12'd3780: screen_char = 8'h45;
                12'd3781: screen_char = 8'h4D;
                12'd3782: screen_char = 8'h4F;
                12'd3783: screen_char = 8'h5D;
                default: screen_char = 8'h20;
            endcase
        end
    endfunction

    wire [6:0] cell_x = x[9:3];
    wire [4:0] cell_y = y[8:4];
    wire [2:0] px = x[2:0];
    wire [3:0] py = y[3:0];
    wire [11:0] address = {cell_y, cell_x};
    // The ROM address is the concatenation of (row[4:0], col[6:0]).
    wire [7:0] ch = screen_char(address);
    wire [34:0] pattern = glyph(ch);
    wire [4:0] font_line = glyph_row(pattern, py[3:1]);
    wire letter_pixel = (px >= 3'd1) && (px <= 3'd5) && font_line[3'd5 - px];
    wire outer_v = (cell_y >= 5'd1 && cell_y <= 5'd28) &&
                   (cell_x == 7'd0 || cell_x == 7'd79) && (px == 3'd3 || px == 3'd4);
    wire middle_v = (cell_y >= 5'd5 && cell_y <= 5'd24) &&
                    (cell_x == 7'd39) && (px == 3'd3 || px == 3'd4);
    wire outer_h = (cell_y == 5'd1 || cell_y == 5'd28) &&
                   (py == 4'd7 || py == 4'd8);
    wire split_h = (cell_y == 5'd4 || cell_y == 5'd24) &&
                   (py == 4'd7 || py == 4'd8);
    wire line_pixel = outer_v || outer_h || middle_v || split_h;

    logic [23:0] color;
    always_comb begin
        color = 24'h061329;
        if (cell_y == 5'd0) color = 24'h152C68;
        else if (cell_y == 5'd29) color = 24'h32215A;
        else if (cell_y >= 5'd5 && cell_y <= 5'd23 && cell_x > 7'd39)
            color = 24'h06252E;
        else if (cell_y >= 5'd5 && cell_y <= 5'd23)
            color = 24'h101E39;
        if (cell_y == 5'd7 && cell_x > 7'd1 && cell_x < 7'd38)
            color = 24'h394D91;
        // Visible hardware color bars between rows of the file panels.
        if (cell_y == 5'd22 && cell_x > 7'd1 && cell_x < 7'd78) begin
            case (cell_x[2:0])
                3'd0: color = 24'hD22632;
                3'd1: color = 24'hF8A12D;
                3'd2: color = 24'hEADA38;
                3'd3: color = 24'h29C658;
                3'd4: color = 24'h1ED7E5;
                3'd5: color = 24'h355DFF;
                3'd6: color = 24'h9347DE;
                default: color = 24'hD24EBE;
            endcase
        end
        if (line_pixel) color = 24'h23C5E8;
        else if (letter_pixel) begin
            if (cell_y == 5'd0) color = 24'hFFF6A0;
            else if (cell_y == 5'd29) color = 24'hE8F2FF;
            else if (cell_y == 5'd7 && cell_x < 7'd39) color = 24'hFFEA64;
            else if (cell_y == 5'd5) color = 24'h26EBD3;
            else if (cell_y == 5'd2) color = 24'hF1AF43;
            else if (cell_y >= 5'd8 && cell_y <= 5'd18 && cell_x < 7'd39) begin
                case (cell_y[2:0])
                    3'd0: color = 24'h33E8F9;
                    3'd1: color = 24'h79FA7B;
                    3'd2: color = 24'hF8D46E;
                    3'd3: color = 24'hF38BC8;
                    default: color = 24'hD9E6FF;
                endcase
            end
            else if (cell_x > 7'd39 && cell_y >= 5'd7 && cell_y <= 5'd21)
                color = 24'h6FFFCF;
            else color = 24'hEBF2FC;
        end
        if (x >= screen_width || y >= screen_height) color = 24'h000000;
    end
    assign red   = w_red'(color[23:16]);
    assign green = w_green'(color[15:8]);
    assign blue  = w_blue'(color[7:0]);
endmodule
