// PiKoSoL Console03 - engineering BRAM terminal candidate.
// USB Host / HDMI / DVI / PLL / pin mapping remain from Console02 / Tetris FIX2.
// No UART, no SDRAM, no physical CPU, no Flash access.
// Screen: 80x30 x 8-bit character ring; one synchronous read and one write.
// DO NOT claim Gowin BUILD PASS or BOARD PASS before operator testing.
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
    localparam [2:0] ST_CLEAR=3'd0, ST_MESSAGE=3'd1,
                     ST_NEXT=3'd2, ST_CLEAR_ROW=3'd3,
                     ST_IDLE=3'd4, ST_RECALL=3'd5;
    reg [2:0] state=ST_CLEAR;
    reg [11:0] clear_addr=0;
    reg [6:0] clear_col=0;
    reg [6:0] msg_pos=0;
    reg [3:0] msg_id=0;
    reg [3:0] next_id=0;
    reg [4:0] top_row=0, current_row=0;
    reg [6:0] cursor_col=0;
    reg [6:0] cmd_len=0;
    reg [7:0] cmd [0:63];
    reg [7:0] history [0:63];
    reg [6:0] hist_len=0;
    reg hist_valid=0;
    reg [6:0] recall_idx=0;
    reg [7:0] held=0;
    reg [24:0] hold_ticks=0;
    reg [7:0] ascii;
    reg key_event;
    reg [7:0] key_code;
    integer i;

    // One saved command. On Up, repaint current input line from history.
    // Keyboard 'repeat' after ~400ms, every ~80ms; only while idle.
    always @* begin
        key_event=1'b0;
        key_code=held;
        if (report_pulse && key0 != 0 && key0 != held) begin
            key_event=1'b1;
            key_code=key0;
        end else if (held != 0 && hold_ticks == 25'd20000000) begin
            key_event=1'b1;
        end
        ascii=8'h00;
        if (key_code >= 8'h04 && key_code <= 8'h1d)
            ascii=8'h41 + (key_code - 8'h04);
        else if (key_code >= 8'h1e && key_code <= 8'h26)
            ascii=8'h31 + (key_code - 8'h1e);
        else if (key_code == 8'h27) ascii=8'h30;
        else if (key_code == 8'h2c) ascii=8'h20;
        else if (key_code == 8'h2d) ascii=8'h2d;
        else if (key_code == 8'h38) ascii=8'h2f;
    end

    function automatic [7:0] message_byte(input [3:0] mid, input [6:0] pos);
        begin
            message_byte=8'h00;
            case(mid)
                4'd0: case(pos)
                    7'd0: message_byte=8'h50;
                    7'd1: message_byte=8'h49;
                    7'd2: message_byte=8'h4B;
                    7'd3: message_byte=8'h4F;
                    7'd4: message_byte=8'h53;
                    7'd5: message_byte=8'h4F;
                    7'd6: message_byte=8'h4C;
                    7'd7: message_byte=8'h20;
                    7'd8: message_byte=8'h32;
                    7'd9: message_byte=8'h35;
                    7'd10: message_byte=8'h4B;
                    7'd11: message_byte=8'h20;
                    7'd12: message_byte=8'h2F;
                    7'd13: message_byte=8'h20;
                    7'd14: message_byte=8'h43;
                    7'd15: message_byte=8'h4F;
                    7'd16: message_byte=8'h4E;
                    7'd17: message_byte=8'h53;
                    7'd18: message_byte=8'h4F;
                    7'd19: message_byte=8'h4C;
                    7'd20: message_byte=8'h45;
                    7'd21: message_byte=8'h30;
                    7'd22: message_byte=8'h33;
                    7'd23: message_byte=8'h20;
                    7'd24: message_byte=8'h2F;
                    7'd25: message_byte=8'h20;
                    7'd26: message_byte=8'h55;
                    7'd27: message_byte=8'h53;
                    7'd28: message_byte=8'h42;
                    7'd29: message_byte=8'h20;
                    7'd30: message_byte=8'h48;
                    7'd31: message_byte=8'h49;
                    7'd32: message_byte=8'h44;
                    default: message_byte=8'h00;
                endcase
                4'd1: case(pos)
                    7'd0: message_byte=8'h48;
                    7'd1: message_byte=8'h44;
                    7'd2: message_byte=8'h4D;
                    7'd3: message_byte=8'h49;
                    7'd4: message_byte=8'h20;
                    7'd5: message_byte=8'h44;
                    7'd6: message_byte=8'h56;
                    7'd7: message_byte=8'h49;
                    7'd8: message_byte=8'h20;
                    7'd9: message_byte=8'h2F;
                    7'd10: message_byte=8'h20;
                    7'd11: message_byte=8'h42;
                    7'd12: message_byte=8'h52;
                    7'd13: message_byte=8'h41;
                    7'd14: message_byte=8'h4D;
                    7'd15: message_byte=8'h20;
                    7'd16: message_byte=8'h38;
                    7'd17: message_byte=8'h30;
                    7'd18: message_byte=8'h58;
                    7'd19: message_byte=8'h33;
                    7'd20: message_byte=8'h30;
                    7'd21: message_byte=8'h20;
                    7'd22: message_byte=8'h2F;
                    7'd23: message_byte=8'h20;
                    7'd24: message_byte=8'h4E;
                    7'd25: message_byte=8'h4F;
                    7'd26: message_byte=8'h20;
                    7'd27: message_byte=8'h55;
                    7'd28: message_byte=8'h41;
                    7'd29: message_byte=8'h52;
                    7'd30: message_byte=8'h54;
                    default: message_byte=8'h00;
                endcase
                4'd2: case(pos)
                    7'd0: message_byte=8'h50;
                    7'd1: message_byte=8'h49;
                    7'd2: message_byte=8'h4B;
                    7'd3: message_byte=8'h4F;
                    7'd4: message_byte=8'h53;
                    7'd5: message_byte=8'h4F;
                    7'd6: message_byte=8'h4C;
                    7'd7: message_byte=8'h3E;
                    7'd8: message_byte=8'h20;
                    default: message_byte=8'h00;
                endcase
                4'd3: case(pos)
                    7'd0: message_byte=8'h48;
                    7'd1: message_byte=8'h45;
                    7'd2: message_byte=8'h4C;
                    7'd3: message_byte=8'h50;
                    7'd4: message_byte=8'h20;
                    7'd5: message_byte=8'h49;
                    7'd6: message_byte=8'h4E;
                    7'd7: message_byte=8'h46;
                    7'd8: message_byte=8'h4F;
                    7'd9: message_byte=8'h20;
                    7'd10: message_byte=8'h43;
                    7'd11: message_byte=8'h4C;
                    7'd12: message_byte=8'h53;
                    7'd13: message_byte=8'h20;
                    7'd14: message_byte=8'h4D;
                    7'd15: message_byte=8'h45;
                    7'd16: message_byte=8'h4D;
                    7'd17: message_byte=8'h20;
                    7'd18: message_byte=8'h53;
                    7'd19: message_byte=8'h54;
                    7'd20: message_byte=8'h41;
                    7'd21: message_byte=8'h54;
                    7'd22: message_byte=8'h55;
                    7'd23: message_byte=8'h53;
                    default: message_byte=8'h00;
                endcase
                4'd4: case(pos)
                    7'd0: message_byte=8'h50;
                    7'd1: message_byte=8'h52;
                    7'd2: message_byte=8'h49;
                    7'd3: message_byte=8'h4D;
                    7'd4: message_byte=8'h45;
                    7'd5: message_byte=8'h52;
                    7'd6: message_byte=8'h20;
                    7'd7: message_byte=8'h32;
                    7'd8: message_byte=8'h35;
                    7'd9: message_byte=8'h4B;
                    7'd10: message_byte=8'h20;
                    7'd11: message_byte=8'h2F;
                    7'd12: message_byte=8'h20;
                    7'd13: message_byte=8'h55;
                    7'd14: message_byte=8'h53;
                    7'd15: message_byte=8'h42;
                    7'd16: message_byte=8'h20;
                    7'd17: message_byte=8'h48;
                    7'd18: message_byte=8'h49;
                    7'd19: message_byte=8'h44;
                    7'd20: message_byte=8'h20;
                    7'd21: message_byte=8'h2B;
                    7'd22: message_byte=8'h20;
                    7'd23: message_byte=8'h48;
                    7'd24: message_byte=8'h44;
                    7'd25: message_byte=8'h4D;
                    7'd26: message_byte=8'h49;
                    7'd27: message_byte=8'h20;
                    7'd28: message_byte=8'h44;
                    7'd29: message_byte=8'h56;
                    7'd30: message_byte=8'h49;
                    default: message_byte=8'h00;
                endcase
                4'd5: case(pos)
                    7'd0: message_byte=8'h42;
                    7'd1: message_byte=8'h52;
                    7'd2: message_byte=8'h41;
                    7'd3: message_byte=8'h4D;
                    7'd4: message_byte=8'h20;
                    7'd5: message_byte=8'h32;
                    7'd6: message_byte=8'h34;
                    7'd7: message_byte=8'h30;
                    7'd8: message_byte=8'h30;
                    7'd9: message_byte=8'h20;
                    7'd10: message_byte=8'h42;
                    7'd11: message_byte=8'h59;
                    7'd12: message_byte=8'h54;
                    7'd13: message_byte=8'h45;
                    7'd14: message_byte=8'h53;
                    7'd15: message_byte=8'h20;
                    7'd16: message_byte=8'h2F;
                    7'd17: message_byte=8'h20;
                    7'd18: message_byte=8'h38;
                    7'd19: message_byte=8'h30;
                    7'd20: message_byte=8'h58;
                    7'd21: message_byte=8'h33;
                    7'd22: message_byte=8'h30;
                    default: message_byte=8'h00;
                endcase
                4'd6: case(pos)
                    7'd0: message_byte=8'h55;
                    7'd1: message_byte=8'h53;
                    7'd2: message_byte=8'h42;
                    7'd3: message_byte=8'h20;
                    7'd4: message_byte=8'h48;
                    7'd5: message_byte=8'h49;
                    7'd6: message_byte=8'h44;
                    7'd7: message_byte=8'h20;
                    7'd8: message_byte=8'h41;
                    7'd9: message_byte=8'h43;
                    7'd10: message_byte=8'h54;
                    7'd11: message_byte=8'h49;
                    7'd12: message_byte=8'h56;
                    7'd13: message_byte=8'h45;
                    7'd14: message_byte=8'h20;
                    7'd15: message_byte=8'h2F;
                    7'd16: message_byte=8'h20;
                    7'd17: message_byte=8'h55;
                    7'd18: message_byte=8'h41;
                    7'd19: message_byte=8'h52;
                    7'd20: message_byte=8'h54;
                    7'd21: message_byte=8'h20;
                    7'd22: message_byte=8'h44;
                    7'd23: message_byte=8'h49;
                    7'd24: message_byte=8'h53;
                    7'd25: message_byte=8'h41;
                    7'd26: message_byte=8'h42;
                    7'd27: message_byte=8'h4C;
                    7'd28: message_byte=8'h45;
                    7'd29: message_byte=8'h44;
                    default: message_byte=8'h00;
                endcase
                4'd7: case(pos)
                    7'd0: message_byte=8'h55;
                    7'd1: message_byte=8'h4E;
                    7'd2: message_byte=8'h4B;
                    7'd3: message_byte=8'h4E;
                    7'd4: message_byte=8'h4F;
                    7'd5: message_byte=8'h57;
                    7'd6: message_byte=8'h4E;
                    7'd7: message_byte=8'h20;
                    7'd8: message_byte=8'h43;
                    7'd9: message_byte=8'h4F;
                    7'd10: message_byte=8'h4D;
                    7'd11: message_byte=8'h4D;
                    7'd12: message_byte=8'h41;
                    7'd13: message_byte=8'h4E;
                    7'd14: message_byte=8'h44;
                    default: message_byte=8'h00;
                endcase
                4'd8: case(pos)
                    7'd0: message_byte=8'h55;
                    7'd1: message_byte=8'h50;
                    7'd2: message_byte=8'h20;
                    7'd3: message_byte=8'h52;
                    7'd4: message_byte=8'h45;
                    7'd5: message_byte=8'h43;
                    7'd6: message_byte=8'h41;
                    7'd7: message_byte=8'h4C;
                    7'd8: message_byte=8'h4C;
                    7'd9: message_byte=8'h53;
                    7'd10: message_byte=8'h20;
                    7'd11: message_byte=8'h4C;
                    7'd12: message_byte=8'h41;
                    7'd13: message_byte=8'h53;
                    7'd14: message_byte=8'h54;
                    7'd15: message_byte=8'h20;
                    7'd16: message_byte=8'h43;
                    7'd17: message_byte=8'h4F;
                    7'd18: message_byte=8'h4D;
                    7'd19: message_byte=8'h4D;
                    7'd20: message_byte=8'h41;
                    7'd21: message_byte=8'h4E;
                    7'd22: message_byte=8'h44;
                    default: message_byte=8'h00;
                endcase
                4'd9: case(pos)
                    7'd0: message_byte=8'h43;
                    7'd1: message_byte=8'h4F;
                    7'd2: message_byte=8'h4E;
                    7'd3: message_byte=8'h53;
                    7'd4: message_byte=8'h4F;
                    7'd5: message_byte=8'h4C;
                    7'd6: message_byte=8'h45;
                    7'd7: message_byte=8'h20;
                    7'd8: message_byte=8'h52;
                    7'd9: message_byte=8'h45;
                    7'd10: message_byte=8'h41;
                    7'd11: message_byte=8'h44;
                    7'd12: message_byte=8'h59;
                    default: message_byte=8'h00;
                endcase
                default: message_byte=8'h00;
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

    // Physically circular text rows avoid costly whole-screen copy on scroll.
    wire [5:0] display_sum={1'b0,top_row}+{1'b0,y[8:4]};
    wire [4:0] display_row = display_sum >= 6'd30 ? display_sum-6'd30 : display_sum[4:0];
    wire [11:0] rd_addr=(display_row*12'd80)+{5'd0,x[9:3]};
    wire [11:0] row_base=(current_row*12'd80);
    reg [7:0] read_char=8'h20;
    reg [2:0] x_delay=0;
    reg [3:0] y_delay=0;
    reg visible_delay=0;
    reg [7:0] wdata;
    reg [11:0] waddr;
    reg we;
    wire [7:0] out_char=message_byte(msg_id,msg_pos);

    always @* begin
        we=1'b0;
        waddr=12'd0;
        wdata=8'h20;
        case(state)
            ST_CLEAR: begin
                we=1'b1; waddr=clear_addr; wdata=8'h20;
            end
            ST_CLEAR_ROW: begin
                we=1'b1; waddr=row_base+{5'd0,clear_col}; wdata=8'h20;
            end
            ST_MESSAGE: if (out_char != 0 && cursor_col < 7'd80) begin
                we=1'b1; waddr=row_base+{5'd0,cursor_col}; wdata=out_char;
            end
            ST_IDLE: if (enable && key_event) begin
                if (key_code==8'h2a && cmd_len!=0) begin
                    we=1'b1; waddr=row_base+{5'd0,cursor_col-1'b1}; wdata=8'h20;
                end else if (ascii!=0 && cmd_len<7'd64 && cursor_col<7'd79) begin
                    we=1'b1; waddr=row_base+{5'd0,cursor_col}; wdata=ascii;
                end
            end
            ST_RECALL: begin
                we=1'b1;
                waddr=row_base+12'd9+{5'd0,recall_idx};
                wdata=(recall_idx<hist_len) ? history[recall_idx] : 8'h20;
            end
            default: begin end
        endcase
    end

    // Gowin RAM inference: only ONE write source and synchronous video read.
    // Read-during-write at same address is not used for control decisions.
    (* syn_ramstyle = "block_ram" *) reg [7:0] vram [0:2399];
    always @(posedge clk) begin
        if (we && waddr<12'd2400) vram[waddr]<=wdata;
        if (rd_addr<12'd2400) read_char<=vram[rd_addr];
        else read_char<=8'h20;
        x_delay<=x[2:0];
        y_delay<=y[3:0];
        visible_delay<=(x<10'd640 && y<10'd480);
    end

    wire [34:0] bitmap=glyph(read_char);
    reg dot;
    integer glyph_index;
    always @* begin
        dot=1'b0;
        glyph_index=0;
        if (x_delay<3'd5 && y_delay>=4'd1 && y_delay<=4'd14) begin
            glyph_index=(6-((y_delay-4'd1)>>1))*5+(4-x_delay);
            dot=bitmap[glyph_index];
        end
        rgb=24'h0B1828;
        if (dot) rgb=24'hD9F9E5;
        if (!visible_delay) rgb=24'h000000;
    end

    always @(posedge clk) begin
        if (rst) begin
            state<=ST_CLEAR;
            clear_addr<=0;
            clear_col<=0;
            top_row<=0;
            current_row<=0;
            cursor_col<=0;
            cmd_len<=0;
            msg_id<=0;
            msg_pos<=0;
            next_id<=0;
            held<=0;
            hold_ticks<=0;
            hist_len<=0;
            hist_valid<=0;
            recall_idx<=0;
        end else begin
            // HID report state is independent of display and message states.
            if (!enable) begin
                held<=0;
                hold_ticks<=0;
            end else if (report_pulse && key0!=held) begin
                held<=key0;
                hold_ticks<=0;
            end else if (held==0) begin
                hold_ticks<=0;
            end else if (hold_ticks==25'd20000000) begin
                hold_ticks<=25'd16000000; // next repeat after ~80ms
            end else hold_ticks<=hold_ticks+1'b1;

            case(state)
                ST_CLEAR: begin
                    if (clear_addr==12'd2399) begin
                        clear_addr<=0;
                        top_row<=0;
                        current_row<=0;
                        cursor_col<=0;
                        cmd_len<=0;
                        msg_id<=0; // header
                        msg_pos<=0;
                        state<=ST_MESSAGE;
                    end else clear_addr<=clear_addr+1'b1;
                end
                ST_MESSAGE: begin
                    if (out_char==0 || cursor_col>=7'd80) begin
                        msg_pos<=0;
                        if (msg_id==4'd2) state<=ST_IDLE; // prompt
                        else begin
                            if (msg_id==4'd0) next_id<=4'd1; // header -> details
                            else if (msg_id==4'd1) next_id<=4'd2; // details -> prompt
                            else next_id<=4'd2; // response -> prompt
                            state<=ST_NEXT;
                        end
                    end else begin
                        msg_pos<=msg_pos+1'b1;
                        cursor_col<=cursor_col+1'b1;
                    end
                end
                ST_NEXT: begin
                    current_row <= (current_row==5'd29) ? 5'd0 : current_row+1'b1;
                    if (current_row==5'd29)
                        top_row <= (top_row==5'd29) ? 5'd0 : top_row+1'b1;
                    clear_col<=0;
                    cursor_col<=0;
                    state<=ST_CLEAR_ROW;
                end
                ST_CLEAR_ROW: begin
                    if (clear_col==7'd79) begin
                        cursor_col<=0;
                        msg_pos<=0;
                        msg_id<=next_id;
                        state<=ST_MESSAGE;
                    end else clear_col<=clear_col+1'b1;
                end
                ST_IDLE: begin
                    if (enable && key_event) begin
                        if (key_code==8'h28) begin // Enter
                            if (cmd_len!=0) begin
                                hist_valid<=1;
                                hist_len<=cmd_len;
                                for (i=0;i<64;i=i+1) history[i]<=cmd[i];
                            end
                            if (cmd_len==3 &&
                                cmd[0]=="C" && cmd[1]=="L" && cmd[2]=="S") begin
                                state<=ST_CLEAR;
                                clear_addr<=0;
                            end else begin
                                if (cmd_len==4 &&
                                    cmd[0]=="H" && cmd[1]=="E" &&
                                    cmd[2]=="L" && cmd[3]=="P") next_id<=4'd3;
                                else if (cmd_len==4 &&
                                    cmd[0]=="I" && cmd[1]=="N" &&
                                    cmd[2]=="F" && cmd[3]=="O") next_id<=4'd4;
                                else if (cmd_len==3 &&
                                    cmd[0]=="M" && cmd[1]=="E" &&
                                    cmd[2]=="M") next_id<=4'd5;
                                else if (cmd_len==6 &&
                                    cmd[0]=="S" && cmd[1]=="T" && cmd[2]=="A" &&
                                    cmd[3]=="T" && cmd[4]=="U" && cmd[5]=="S") next_id<=4'd6;
                                else if (cmd_len==0) next_id<=4'd2;
                                else next_id<=4'd7;
                                state<=ST_NEXT;
                            end
                            cmd_len<=0;
                        end else if (key_code==8'h2a && cmd_len!=0) begin // Backspace
                            cmd_len<=cmd_len-1'b1;
                            cursor_col<=cursor_col-1'b1;
                        end else if (key_code==8'h52 && hist_valid) begin // Up
                            recall_idx<=0;
                            state<=ST_RECALL;
                        end else if (ascii!=0 && cmd_len<7'd64 && cursor_col<7'd79) begin
                            cmd[cmd_len]<=ascii;
                            cmd_len<=cmd_len+1'b1;
                            cursor_col<=cursor_col+1'b1;
                        end
                    end
                end
                ST_RECALL: begin
                    // Prompt occupies columns 0..8; remaining 64 bytes rebuilt.
                    cmd[recall_idx]<=history[recall_idx];
                    if (recall_idx==7'd63) begin
                        cmd_len<=hist_len;
                        cursor_col<=7'd9+hist_len;
                        state<=ST_IDLE;
                    end else recall_idx<=recall_idx+1'b1;
                end
                default: state<=ST_CLEAR;
            endcase
        end
    end
endmodule
