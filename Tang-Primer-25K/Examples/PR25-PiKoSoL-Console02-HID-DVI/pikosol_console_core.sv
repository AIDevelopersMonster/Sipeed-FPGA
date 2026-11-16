// PiKoSoL Console02: first USB-keyboard-only command monitor.
// Engineering candidate, derived from BOARD-PASS Tetris FIX2 USB/DVI shell.
// No UART, no external SDRAM, no 2400-byte multi-write VRAM.
// Uppercase US HID keyboard usage; 16-character command buffer; no USB hub.
module pikosol_console_core (
    input wire clk,
    input wire rst,
    input wire enable,
    input wire report_pulse,
    input wire [7:0] key0,
    input wire [7:0] modifiers,
    input wire [9:0] x,
    input wire [9:0] y,
    output reg [23:0] rgb
);
    reg [7:0] command [0:15];
    reg [4:0] cmd_len = 0;
    reg [31:0] tail = 0;
    reg [7:0] previous_key = 0;
    reg [1:0] answer = 0; // 0: hint, 1: help, 2: info, 3: unknown
    reg cleared = 0;
    wire new_press = enable && report_pulse && key0 != 0 && key0 != previous_key;
    wire [7:0] ascii =
        (key0 >= 8'h04 && key0 <= 8'h1d) ? (8'h41 + key0 - 8'h04) :
        (key0 >= 8'h1e && key0 <= 8'h26) ? (8'h31 + key0 - 8'h1e) :
        (key0 == 8'h27) ? 8'h30 :
        (key0 == 8'h2c) ? 8'h20 : 8'h00;
    integer i;
    always @(posedge clk) begin
        if (rst) begin
            previous_key <= 0;
            cmd_len <= 0;
            tail <= 0;
            answer <= 0;
            cleared <= 0;
            for (i=0;i<16;i=i+1) command[i] <= 8'h20;
        end else if (!enable) begin
            previous_key <= 0;
        end else if (report_pulse) begin
            previous_key <= key0;
            if (new_press) begin
                if (key0 == 8'h28) begin // Enter
                    if (cmd_len == 4 && tail == 32'h48454c50) begin
                        answer <= 1; cleared <= 0;
                    end else if (cmd_len == 4 && tail == 32'h494e464f) begin
                        answer <= 2; cleared <= 0;
                    end else if (cmd_len == 3 && tail[23:0] == 24'h434c53) begin
                        answer <= 0; cleared <= 1;
                    end else if (cmd_len != 0) begin
                        answer <= 3; cleared <= 0;
                    end
                    cmd_len <= 0;
                    tail <= 0;
                    for (i=0;i<16;i=i+1) command[i] <= 8'h20;
                end else if (key0 == 8'h2a) begin // Backspace
                    if (cmd_len != 0) begin
                        cmd_len <= cmd_len - 1'b1;
                        command[cmd_len-1'b1] <= 8'h20;
                        // Backspace recomputes last 4 chars for command match.
                        if (cmd_len <= 4) tail <= tail >> 8;
                        else tail <= {command[cmd_len-5],command[cmd_len-4],command[cmd_len-3],command[cmd_len-2]};
                    end
                end else if (ascii != 0 && cmd_len < 16) begin
                    command[cmd_len] <= ascii;
                    cmd_len <= cmd_len + 1'b1;
                    tail <= {tail[23:0],ascii};
                end
            end
        end
    end
    function automatic [7:0] static_char(input [4:0] row, input [6:0] col);
        begin
            static_char = 8'h20;
            case(row)
                5'd0: begin
                    case(col)
                        7'd0: static_char=8'h50;
                        7'd1: static_char=8'h49;
                        7'd2: static_char=8'h4b;
                        7'd3: static_char=8'h4f;
                        7'd4: static_char=8'h53;
                        7'd5: static_char=8'h4f;
                        7'd6: static_char=8'h4c;
                        7'd8: static_char=8'h32;
                        7'd9: static_char=8'h35;
                        7'd10: static_char=8'h4b;
                        7'd12: static_char=8'h2d;
                        7'd14: static_char=8'h55;
                        7'd15: static_char=8'h53;
                        7'd16: static_char=8'h42;
                        7'd18: static_char=8'h43;
                        7'd19: static_char=8'h4f;
                        7'd20: static_char=8'h4e;
                        7'd21: static_char=8'h53;
                        7'd22: static_char=8'h4f;
                        7'd23: static_char=8'h4c;
                        7'd24: static_char=8'h45;
                        default: static_char=8'h20;
                    endcase
                end
                5'd2: begin
                    case(col)
                        7'd0: static_char=8'h54;
                        7'd1: static_char=8'h41;
                        7'd2: static_char=8'h4e;
                        7'd3: static_char=8'h47;
                        7'd5: static_char=8'h50;
                        7'd6: static_char=8'h52;
                        7'd7: static_char=8'h49;
                        7'd8: static_char=8'h4d;
                        7'd9: static_char=8'h45;
                        7'd10: static_char=8'h52;
                        7'd12: static_char=8'h32;
                        7'd13: static_char=8'h35;
                        7'd14: static_char=8'h4b;
                        7'd17: static_char=8'h48;
                        7'd18: static_char=8'h44;
                        7'd19: static_char=8'h4d;
                        7'd20: static_char=8'h49;
                        7'd21: static_char=8'h2b;
                        7'd22: static_char=8'h44;
                        7'd23: static_char=8'h56;
                        7'd24: static_char=8'h49;
                        7'd27: static_char=8'h55;
                        7'd28: static_char=8'h53;
                        7'd29: static_char=8'h42;
                        7'd31: static_char=8'h48;
                        7'd32: static_char=8'h49;
                        7'd33: static_char=8'h44;
                        default: static_char=8'h20;
                    endcase
                end
                5'd4: begin
                    case(col)
                        7'd0: static_char=8'h53;
                        7'd1: static_char=8'h31;
                        7'd2: static_char=8'h3a;
                        7'd4: static_char=8'h55;
                        7'd5: static_char=8'h53;
                        7'd6: static_char=8'h42;
                        7'd8: static_char=8'h48;
                        7'd9: static_char=8'h4f;
                        7'd10: static_char=8'h53;
                        7'd11: static_char=8'h54;
                        7'd15: static_char=8'h46;
                        7'd16: static_char=8'h31;
                        7'd17: static_char=8'h3a;
                        7'd19: static_char=8'h48;
                        7'd20: static_char=8'h49;
                        7'd21: static_char=8'h44;
                        7'd23: static_char=8'h44;
                        7'd24: static_char=8'h49;
                        7'd25: static_char=8'h41;
                        7'd26: static_char=8'h47;
                        default: static_char=8'h20;
                    endcase
                end
                5'd6: begin
                    case(col)
                        7'd0: static_char=8'h43;
                        7'd1: static_char=8'h4f;
                        7'd2: static_char=8'h4d;
                        7'd3: static_char=8'h4d;
                        7'd4: static_char=8'h41;
                        7'd5: static_char=8'h4e;
                        7'd6: static_char=8'h44;
                        7'd7: static_char=8'h53;
                        7'd8: static_char=8'h3a;
                        7'd10: static_char=8'h48;
                        7'd11: static_char=8'h45;
                        7'd12: static_char=8'h4c;
                        7'd13: static_char=8'h50;
                        7'd15: static_char=8'h49;
                        7'd16: static_char=8'h4e;
                        7'd17: static_char=8'h46;
                        7'd18: static_char=8'h4f;
                        7'd20: static_char=8'h43;
                        7'd21: static_char=8'h4c;
                        7'd22: static_char=8'h53;
                        default: static_char=8'h20;
                    endcase
                end
                5'd8: begin
                    case(col)
                        7'd0: static_char=8'h50;
                        7'd1: static_char=8'h49;
                        7'd2: static_char=8'h4b;
                        7'd3: static_char=8'h4f;
                        7'd4: static_char=8'h53;
                        7'd5: static_char=8'h4f;
                        7'd6: static_char=8'h4c;
                        7'd7: static_char=8'h3e;
                        default: static_char=8'h20;
                    endcase
                end
                5'd10: begin
                    case(col)
                        7'd0: static_char=8'h54;
                        7'd1: static_char=8'h59;
                        7'd2: static_char=8'h50;
                        7'd3: static_char=8'h45;
                        7'd5: static_char=8'h41;
                        7'd7: static_char=8'h43;
                        7'd8: static_char=8'h4f;
                        7'd9: static_char=8'h4d;
                        7'd10: static_char=8'h4d;
                        7'd11: static_char=8'h41;
                        7'd12: static_char=8'h4e;
                        7'd13: static_char=8'h44;
                        7'd15: static_char=8'h41;
                        7'd16: static_char=8'h4e;
                        7'd17: static_char=8'h44;
                        7'd19: static_char=8'h50;
                        7'd20: static_char=8'h52;
                        7'd21: static_char=8'h45;
                        7'd22: static_char=8'h53;
                        7'd23: static_char=8'h53;
                        7'd25: static_char=8'h45;
                        7'd26: static_char=8'h4e;
                        7'd27: static_char=8'h54;
                        7'd28: static_char=8'h45;
                        7'd29: static_char=8'h52;
                        default: static_char=8'h20;
                    endcase
                end
                5'd12: begin
                    case(col)
                        7'd0: static_char=8'h48;
                        7'd1: static_char=8'h45;
                        7'd2: static_char=8'h4c;
                        7'd3: static_char=8'h50;
                        7'd4: static_char=8'h3a;
                        7'd6: static_char=8'h48;
                        7'd7: static_char=8'h45;
                        7'd8: static_char=8'h4c;
                        7'd9: static_char=8'h50;
                        7'd11: static_char=8'h49;
                        7'd12: static_char=8'h4e;
                        7'd13: static_char=8'h46;
                        7'd14: static_char=8'h4f;
                        7'd16: static_char=8'h43;
                        7'd17: static_char=8'h4c;
                        7'd18: static_char=8'h53;
                        default: static_char=8'h20;
                    endcase
                end
                5'd13: begin
                    case(col)
                        7'd0: static_char=8'h49;
                        7'd1: static_char=8'h4e;
                        7'd2: static_char=8'h46;
                        7'd3: static_char=8'h4f;
                        7'd4: static_char=8'h3a;
                        7'd6: static_char=8'h32;
                        7'd7: static_char=8'h35;
                        7'd8: static_char=8'h4b;
                        7'd10: static_char=8'h55;
                        7'd11: static_char=8'h53;
                        7'd12: static_char=8'h42;
                        7'd14: static_char=8'h48;
                        7'd15: static_char=8'h49;
                        7'd16: static_char=8'h44;
                        7'd18: static_char=8'h44;
                        7'd19: static_char=8'h56;
                        7'd20: static_char=8'h49;
                        7'd22: static_char=8'h36;
                        7'd23: static_char=8'h34;
                        7'd24: static_char=8'h30;
                        7'd25: static_char=8'h58;
                        7'd26: static_char=8'h34;
                        7'd27: static_char=8'h38;
                        7'd28: static_char=8'h30;
                        default: static_char=8'h20;
                    endcase
                end
                5'd14: begin
                    case(col)
                        7'd0: static_char=8'h43;
                        7'd1: static_char=8'h4c;
                        7'd2: static_char=8'h53;
                        7'd3: static_char=8'h3a;
                        7'd5: static_char=8'h52;
                        7'd6: static_char=8'h45;
                        7'd7: static_char=8'h53;
                        7'd8: static_char=8'h45;
                        7'd9: static_char=8'h54;
                        7'd11: static_char=8'h43;
                        7'd12: static_char=8'h4f;
                        7'd13: static_char=8'h4d;
                        7'd14: static_char=8'h4d;
                        7'd15: static_char=8'h41;
                        7'd16: static_char=8'h4e;
                        7'd17: static_char=8'h44;
                        7'd19: static_char=8'h41;
                        7'd20: static_char=8'h52;
                        7'd21: static_char=8'h45;
                        7'd22: static_char=8'h41;
                        default: static_char=8'h20;
                    endcase
                end
                5'd15: begin
                    case(col)
                        7'd0: static_char=8'h55;
                        7'd1: static_char=8'h4e;
                        7'd2: static_char=8'h4b;
                        7'd3: static_char=8'h4e;
                        7'd4: static_char=8'h4f;
                        7'd5: static_char=8'h57;
                        7'd6: static_char=8'h4e;
                        7'd8: static_char=8'h43;
                        7'd9: static_char=8'h4f;
                        7'd10: static_char=8'h4d;
                        7'd11: static_char=8'h4d;
                        7'd12: static_char=8'h41;
                        7'd13: static_char=8'h4e;
                        7'd14: static_char=8'h44;
                        default: static_char=8'h20;
                    endcase
                end
                default: static_char=8'h20;
            endcase
        end
    endfunction

    function automatic [34:0] glyph(input [7:0] ch);
        begin
            case(ch)
                8'h30: glyph=35'b01110_10001_10011_10101_11001_10001_01110;
                8'h31: glyph=35'b00100_01100_00100_00100_00100_00100_01110;
                8'h32: glyph=35'b01110_10001_00001_00010_00100_01000_11111;
                8'h33: glyph=35'b11110_00001_00001_01110_00001_00001_11110;
                8'h34: glyph=35'b00010_00110_01010_10010_11111_00010_00010;
                8'h35: glyph=35'b11111_10000_10000_11110_00001_00001_11110;
                8'h36: glyph=35'b01111_10000_10000_11110_10001_10001_01110;
                8'h37: glyph=35'b11111_00001_00010_00100_01000_01000_01000;
                8'h38: glyph=35'b01110_10001_10001_01110_10001_10001_01110;
                8'h39: glyph=35'b01110_10001_10001_01111_00001_00001_11110;
                8'h20: glyph=35'b00000_00000_00000_00000_00000_00000_00000;
                8'h41: glyph=35'b01110_10001_10001_11111_10001_10001_10001;
                8'h42: glyph=35'b11110_10001_10001_11110_10001_10001_11110;
                8'h43: glyph=35'b01111_10000_10000_10000_10000_10000_01111;
                8'h44: glyph=35'b11110_10001_10001_10001_10001_10001_11110;
                8'h45: glyph=35'b11111_10000_10000_11110_10000_10000_11111;
                8'h46: glyph=35'b11111_10000_10000_11110_10000_10000_10000;
                8'h47: glyph=35'b01111_10000_10000_10111_10001_10001_01110;
                8'h48: glyph=35'b10001_10001_10001_11111_10001_10001_10001;
                8'h49: glyph=35'b01110_00100_00100_00100_00100_00100_01110;
                8'h4a: glyph=35'b00111_00010_00010_00010_10010_10010_01100;
                8'h4b: glyph=35'b10001_10010_10100_11000_10100_10010_10001;
                8'h4c: glyph=35'b10000_10000_10000_10000_10000_10000_11111;
                8'h4d: glyph=35'b10001_11011_10101_10101_10001_10001_10001;
                8'h4e: glyph=35'b10001_11001_10101_10011_10001_10001_10001;
                8'h4f: glyph=35'b01110_10001_10001_10001_10001_10001_01110;
                8'h50: glyph=35'b11110_10001_10001_11110_10000_10000_10000;
                8'h51: glyph=35'b01110_10001_10001_10001_10101_10010_01101;
                8'h52: glyph=35'b11110_10001_10001_11110_10100_10010_10001;
                8'h53: glyph=35'b01111_10000_10000_01110_00001_00001_11110;
                8'h54: glyph=35'b11111_00100_00100_00100_00100_00100_00100;
                8'h55: glyph=35'b10001_10001_10001_10001_10001_10001_01110;
                8'h56: glyph=35'b10001_10001_10001_10001_10001_01010_00100;
                8'h57: glyph=35'b10001_10001_10001_10101_10101_10101_01010;
                8'h58: glyph=35'b10001_10001_01010_00100_01010_10001_10001;
                8'h59: glyph=35'b10001_10001_01010_00100_00100_00100_00100;
                8'h5a: glyph=35'b11111_00001_00010_00100_01000_10000_11111;
                8'h3e: glyph=35'b10000_01000_00100_00010_00100_01000_10000;
                8'h3a: glyph=35'b00000_00100_00100_00000_00100_00100_00000;
                8'h2d: glyph=35'b00000_00000_00000_11111_00000_00000_00000;
                8'h2b: glyph=35'b00000_00100_00100_11111_00100_00100_00000;
                8'h2f: glyph=35'b00001_00001_00010_00100_01000_10000_10000;
                8'h3f: glyph=35'b01110_10001_00001_00010_00100_00000_00100;
                8'h2e: glyph=35'b00000_00000_00000_00000_00000_01100_01100;
                8'h3d: glyph=35'b00000_11111_00000_11111_00000_00000_00000;
                8'h5f: glyph=35'b00000_00000_00000_00000_00000_00000_11111;
                default: glyph=35'b0;
            endcase
        end
    endfunction

    wire [6:0] col = x[9:3];
    wire [4:0] row = y[8:4];
    wire [2:0] cell_x = x[2:0];
    wire [3:0] cell_y = y[3:0];
    reg [7:0] ch;
    reg [34:0] bitmap;
    reg dot;
    always @* begin
        ch=8'h20;
        if (row == 5'd8) begin
            if (col < 7'd9) ch=static_char(row,col);
            else if (col < 7'd25) ch=command[col-7'd9];
            else if (col == 7'd25 && cmd_len == 16) ch=8'h5f;
        end else if (!cleared && (row <= 5'd6 || row == 5'd10)) begin
            ch=static_char(row,col);
        end else if (row >= 5'd12 && row <= 5'd15) begin
            if (!cleared && ((answer==1 && row==12) ||
                             (answer==2 && row==13) ||
                             (answer==3 && row==15)))
                ch=static_char(row,col);
        end
        bitmap = glyph(ch);
        dot = 1'b0;
        if (cell_x < 3'd5 && cell_y >= 4'd1 && cell_y <= 4'd14)
            dot = bitmap[(6-(cell_y-4'd1)/2)*5+(4-cell_x)];
        rgb = 24'h0b1725;
        if (row == 0 && !cleared) rgb=24'h173e65;
        if (dot) rgb = (row==8) ? 24'h88f3c4 : 24'he1edf6;
        if (x>=10'd640 || y>=10'd480) rgb=24'h000000;
    end
endmodule
