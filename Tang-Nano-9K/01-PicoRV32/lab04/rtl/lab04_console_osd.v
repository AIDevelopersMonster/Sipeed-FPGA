// PiKoSoL LAB-04.3.1B v0.1.8b: TERM/GFX modes and pixel-domain 32x76 line VRAM.
// 640x480, BGR888. A lossless 8-bit handshake CDC receives UART tap data.
// All text RAM access (write and read) uses clk_pixel only.
// Two registered pixel stages: output remains stable across downstream stalls.
// TERM: 29 visible 76-char rows; GFX: top menu, right status, 4-row log.
// Graphics A/B are visible only in GFX mode, behind the text overlay.
// No ANSI; LF, CR, BS, FF plus CPU-only mode controls SO/SI. Ring has 32 rows.
// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module lab04_console_osd (
    input wire clk_sys, input wire resetn_sys,
    input wire clk_pixel, input wire resetn_pixel,
    input wire char_valid, output wire char_ready, input wire [7:0] char_data,
    input wire [5:0] led_mask_pixel,
    input wire gfx_event_valid, input wire [3:0] gfx_event_index,
    input wire [23:0] gfx_event_value,
    input wire s_axis_tvalid, output wire s_axis_tready,
    input wire [23:0] s_axis_tdata, input wire [0:0] s_axis_tuser,
    output wire m_axis_tvalid, input wire m_axis_tready,
    output wire [23:0] m_axis_tdata, output wire [0:0] m_axis_tuser
);
    localparam integer LOG_COLS = 76;
    localparam integer LOG_SIZE = 2432;
    reg [7:0] log_mem [0:LOG_SIZE-1] /* synthesis syn_ramstyle = "block_ram" */;
    reg clearing;
    reg clear_all;
    reg [11:0] clear_pos;
    reg [4:0] clear_row;
    reg [4:0] wr_row;
    reg shell_term; // 1=full terminal, 0=graphics monitor
    reg [6:0] wr_col;
    wire [11:0] clr_addr;
    wire [11:0] wr_addr;
    wire write_backspace;
    wire write_printable;
    wire mem_write_en;
    wire [11:0] mem_write_addr;
    wire [7:0] mem_write_data;
    wire char_event_valid;
    wire [7:0] char_event_byte;

    function [11:0] row_base;
        input [4:0] row;
        begin
            // Multiply by 76 = 64 + 8 + 4, no general divider/multiplier.
            row_base=({7'b0,row}<<6)+({7'b0,row}<<3)+({7'b0,row}<<2);
        end
    endfunction
    assign clr_addr = clear_all ? clear_pos : row_base(clear_row)+clear_pos;
    assign wr_addr = row_base(wr_row)+{5'b0,wr_col};

    // One true write port, with a separate synchronous video read port.
    // No asynchronous reset or unconditional clearing on RAM itself:
    // the pixel parser clears 2432 locations sequentially after reset.
    assign write_backspace = !clearing && char_event_valid &&
                             (char_event_byte == 8'h08) && (wr_col != 0);
    assign write_printable = !clearing && char_event_valid &&
                             (char_event_byte >= 8'h20) && (char_event_byte <= 8'h7e);
    assign mem_write_en = clearing || write_backspace || write_printable;
    assign mem_write_addr = clearing ? clr_addr :
                      (write_backspace ? wr_addr-12'd1 : wr_addr);
    assign mem_write_data = write_printable ? char_event_byte : 8'h20;
    always @(posedge clk_pixel) begin
        if (mem_write_en) log_mem[mem_write_addr] <= mem_write_data;
    end

    lab04_tty_byte_cdc u_tty_cdc (
        .clk_sys(clk_sys), .resetn_sys(resetn_sys),
        .char_valid(char_valid), .char_ready(char_ready), .char_data(char_data),
        .clk_pixel(clk_pixel), .resetn_pixel(resetn_pixel),
        .pixel_accept(!clearing),
        .event_valid(char_event_valid), .event_byte(char_event_byte)
    );

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            clearing <= 1'b1;
            clear_all <= 1'b1;
            shell_term <= 1'b1;
            clear_pos <= 12'd0;
            clear_row <= 5'd0;
            wr_row <= 5'd31;
            wr_col <= 7'd0;
        end else if (clearing) begin
            if ((clear_all && clear_pos == 12'd2431) ||
                (!clear_all && clear_pos == 12'd75)) begin
                clear_pos <= 12'd0;
                clearing <= 1'b0;
                clear_all <= 1'b0;
            end else begin
                clear_pos <= clear_pos + 1'b1;
            end
        end else if (char_event_valid) begin
            case (char_event_byte)
                8'h0e: shell_term <= 1'b1; // TERM output from CPU only
                8'h0f: shell_term <= 1'b0; // GFX output from CPU only
                8'h0c: begin // form feed: clear the whole log
                    wr_col <= 7'd0;
                    wr_row <= 5'd31;
                    clear_pos <= 12'd0;
                    clear_all <= 1'b1;
                    clearing <= 1'b1;
                end
                8'h0d: wr_col <= 7'd0;
                8'h0a: begin // LF: advance to and clear the next row
                    wr_col <= 7'd0;
                    wr_row <= wr_row + 5'd1;
                    clear_row <= wr_row + 5'd1;
                    clear_pos <= 12'd0;
                    clear_all <= 1'b0;
                    clearing <= 1'b1;
                end
                8'h08: begin // BS: erase previous character
                    if (wr_col != 0) begin
                        wr_col <= wr_col - 1'b1;
                    end
                end
                default: begin
                    if (char_event_byte >= 8'h20 && char_event_byte <= 8'h7e) begin
                        if (wr_col == 7'd75) begin
                            wr_col <= 7'd0;
                            wr_row <= wr_row + 5'd1;
                            clear_row <= wr_row + 5'd1;
                            clear_pos <= 12'd0;
                            clear_all <= 1'b0;
                            clearing <= 1'b1;
                        end else begin
                            wr_col <= wr_col + 1'b1;
                        end
                    end
                end
            endcase
        end
    end

    // Status mirror of the graphics mailbox. It is a local pixel-clock-only
    // mirror, frame-snapshotted only after commit index=15 (like graphic OSD).
    reg [9:0] ax_stage, ay_stage, bx_stage, by_stage;
    reg [23:0] ac_stage, bc_stage;
    reg [2:0] act_stage, bct_stage;
    reg select_b_stage, commit_pending;
    reg [9:0] shown_x, shown_y;
    reg [23:0] shown_color;
    reg [2:0] shown_mode;
    reg shown_sel_b;
    reg [5:0] shown_led;
    reg [9:0] xpos;
    reg [8:0] ypos;
    reg [5:0] text_row;
    reg [3:0] glyph_line;
    wire [9:0] px = s_axis_tuser[0] ? 10'd0 : xpos;
    wire [8:0] py = s_axis_tuser[0] ? 9'd0 : ypos;
    wire [5:0] cy = s_axis_tuser[0] ? 6'd0 : text_row;
    wire [3:0] sy = s_axis_tuser[0] ? 4'd0 : glyph_line;
    wire [6:0] cx = px[9:3];
    wire fire_in = s_axis_tvalid && s_axis_tready;

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            xpos<=0; ypos<=0; text_row<=0; glyph_line<=0;
            ax_stage<=0; ay_stage<=0; bx_stage<=0; by_stage<=0;
            ac_stage<=0; bc_stage<=0; act_stage<=0; bct_stage<=0;
            select_b_stage<=0; commit_pending<=0;
            shown_x<=0; shown_y<=0; shown_color<=0;
            shown_mode<=0; shown_sel_b<=0; shown_led<=0;
        end else begin
            if (gfx_event_valid) begin
                case (gfx_event_index)
                    4'd0: ax_stage<=gfx_event_value[9:0];
                    4'd1: ay_stage<=gfx_event_value[9:0];
                    4'd4: ac_stage<=gfx_event_value;
                    4'd5: act_stage<=gfx_event_value[2:0];
                    4'd8: bx_stage<=gfx_event_value[9:0];
                    4'd9: by_stage<=gfx_event_value[9:0];
                    4'd12: bc_stage<=gfx_event_value;
                    4'd13: bct_stage<=gfx_event_value[2:0];
                    4'd15: commit_pending<=1'b1;
                    default: ;
                endcase
                if ((gfx_event_index <= 4'd5)) select_b_stage<=1'b0;
                else if ((gfx_event_index >= 4'd8) && (gfx_event_index <= 4'd13))
                    select_b_stage<=1'b1;
            end
            if (fire_in) begin
                if (s_axis_tuser[0]) begin
                    xpos<=10'd1; ypos<=0; text_row<=0; glyph_line<=0;
                    shown_led<=led_mask_pixel;
                    if (commit_pending) begin
                        shown_x<=select_b_stage ? bx_stage:ax_stage;
                        shown_y<=select_b_stage ? by_stage:ay_stage;
                        shown_color<=select_b_stage ? bc_stage:ac_stage;
                        shown_mode<=select_b_stage ? bct_stage:act_stage;
                        shown_sel_b<=select_b_stage;
                        commit_pending <= (gfx_event_valid && gfx_event_index == 4'd15);
                    end
                end else if (xpos==10'd639) begin
                    xpos<=0;
                    ypos<=(ypos==9'd479) ? 9'd0 : ypos+1'b1;
                    if (glyph_line==4'd11) begin
                        glyph_line<=0;
                        text_row<=(text_row==6'd39) ? 5'd0 : text_row+1'b1;
                    end else glyph_line<=glyph_line+1'b1;
                end else xpos<=xpos+1'b1;
            end
        end
    end

    function [7:0] hexascii;
        input [3:0] nibble;
        begin hexascii=(nibble<10) ? (8'h30+{4'b0,nibble}) :
                              (8'h41+{4'b0,nibble}-8'd10); end
    endfunction

    function [7:0] static_char;
        input [5:0] row;
        input [6:0] col;
        begin
            static_char=8'h20;
            if (row==0 || row==3 || row==7) begin
                if (col==0 || col==79) static_char=8'h2b;
                else static_char=8'h2d;
            end else if (row==10 || row==26) begin
                if (col==59 || col==79) static_char=8'h2b;
                else if (col>59 && col<79) static_char=8'h2d;
            end else if (row>=1 && row<=6 && col==79) begin
                static_char=8'h7c;
            end else begin
                case ({row,col})
                    12'd128: static_char=8'h7c;
                    12'd130: static_char=8'h50;
                    12'd131: static_char=8'h69;
                    12'd132: static_char=8'h4b;
                    12'd133: static_char=8'h6f;
                    12'd134: static_char=8'h53;
                    12'd135: static_char=8'h6f;
                    12'd136: static_char=8'h4c;
                    12'd139: static_char=8'h76;
                    12'd140: static_char=8'h30;
                    12'd141: static_char=8'h2e;
                    12'd142: static_char=8'h31;
                    12'd143: static_char=8'h2e;
                    12'd144: static_char=8'h38;
                    12'd145: static_char=8'h62;
                    12'd148: static_char=8'h7c;
                    12'd150: static_char=8'h50;
                    12'd151: static_char=8'h69;
                    12'd152: static_char=8'h63;
                    12'd153: static_char=8'h6f;
                    12'd154: static_char=8'h52;
                    12'd155: static_char=8'h56;
                    12'd156: static_char=8'h33;
                    12'd157: static_char=8'h32;
                    12'd160: static_char=8'h52;
                    12'd161: static_char=8'h56;
                    12'd162: static_char=8'h33;
                    12'd163: static_char=8'h32;
                    12'd164: static_char=8'h49;
                    12'd167: static_char=8'h7c;
                    12'd169: static_char=8'h54;
                    12'd170: static_char=8'h61;
                    12'd171: static_char=8'h6e;
                    12'd172: static_char=8'h67;
                    12'd174: static_char=8'h4e;
                    12'd175: static_char=8'h61;
                    12'd176: static_char=8'h6e;
                    12'd177: static_char=8'h6f;
                    12'd179: static_char=8'h39;
                    12'd180: static_char=8'h4b;
                    12'd183: static_char=8'h7c;
                    12'd185: static_char=8'h48;
                    12'd186: static_char=8'h44;
                    12'd187: static_char=8'h4d;
                    12'd188: static_char=8'h49;
                    12'd190: static_char=8'h36;
                    12'd191: static_char=8'h34;
                    12'd192: static_char=8'h30;
                    12'd193: static_char=8'h78;
                    12'd194: static_char=8'h34;
                    12'd195: static_char=8'h38;
                    12'd196: static_char=8'h30;
                    12'd256: static_char=8'h7c;
                    12'd258: static_char=8'h46;
                    12'd259: static_char=8'h50;
                    12'd260: static_char=8'h47;
                    12'd261: static_char=8'h41;
                    12'd263: static_char=8'h4d;
                    12'd264: static_char=8'h4f;
                    12'd265: static_char=8'h4e;
                    12'd266: static_char=8'h49;
                    12'd267: static_char=8'h54;
                    12'd268: static_char=8'h4f;
                    12'd269: static_char=8'h52;
                    12'd270: static_char=8'h3a;
                    12'd272: static_char=8'h43;
                    12'd273: static_char=8'h50;
                    12'd274: static_char=8'h55;
                    12'd276: static_char=8'h2b;
                    12'd278: static_char=8'h36;
                    12'd280: static_char=8'h4c;
                    12'd281: static_char=8'h45;
                    12'd282: static_char=8'h44;
                    12'd284: static_char=8'h2b;
                    12'd286: static_char=8'h47;
                    12'd287: static_char=8'h52;
                    12'd288: static_char=8'h41;
                    12'd289: static_char=8'h50;
                    12'd290: static_char=8'h48;
                    12'd291: static_char=8'h49;
                    12'd292: static_char=8'h43;
                    12'd293: static_char=8'h53;
                    12'd295: static_char=8'h41;
                    12'd296: static_char=8'h2f;
                    12'd297: static_char=8'h42;
                    12'd299: static_char=8'h2b;
                    12'd301: static_char=8'h55;
                    12'd302: static_char=8'h41;
                    12'd303: static_char=8'h52;
                    12'd304: static_char=8'h54;
                    12'd306: static_char=8'h4d;
                    12'd307: static_char=8'h49;
                    12'd308: static_char=8'h52;
                    12'd309: static_char=8'h52;
                    12'd310: static_char=8'h4f;
                    12'd311: static_char=8'h52;
                    12'd512: static_char=8'h7c;
                    12'd514: static_char=8'h5b;
                    12'd515: static_char=8'h30;
                    12'd516: static_char=8'h2d;
                    12'd517: static_char=8'h36;
                    12'd518: static_char=8'h5d;
                    12'd520: static_char=8'h4c;
                    12'd521: static_char=8'h45;
                    12'd522: static_char=8'h44;
                    12'd524: static_char=8'h43;
                    12'd525: static_char=8'h4f;
                    12'd526: static_char=8'h55;
                    12'd527: static_char=8'h4e;
                    12'd528: static_char=8'h54;
                    12'd534: static_char=8'h5b;
                    12'd535: static_char=8'h61;
                    12'd536: static_char=8'h2d;
                    12'd537: static_char=8'h66;
                    12'd538: static_char=8'h5d;
                    12'd540: static_char=8'h4f;
                    12'd541: static_char=8'h4e;
                    12'd542: static_char=8'h45;
                    12'd544: static_char=8'h4c;
                    12'd545: static_char=8'h45;
                    12'd546: static_char=8'h44;
                    12'd552: static_char=8'h5b;
                    12'd553: static_char=8'h3f;
                    12'd554: static_char=8'h5d;
                    12'd556: static_char=8'h4d;
                    12'd557: static_char=8'h41;
                    12'd558: static_char=8'h53;
                    12'd559: static_char=8'h4b;
                    12'd640: static_char=8'h7c;
                    12'd642: static_char=8'h5b;
                    12'd643: static_char=8'h41;
                    12'd644: static_char=8'h2f;
                    12'd645: static_char=8'h42;
                    12'd646: static_char=8'h5d;
                    12'd648: static_char=8'h4f;
                    12'd649: static_char=8'h42;
                    12'd650: static_char=8'h4a;
                    12'd651: static_char=8'h45;
                    12'd652: static_char=8'h43;
                    12'd653: static_char=8'h54;
                    12'd661: static_char=8'h5b;
                    12'd662: static_char=8'h69;
                    12'd663: static_char=8'h2f;
                    12'd664: static_char=8'h6a;
                    12'd665: static_char=8'h2f;
                    12'd666: static_char=8'h6b;
                    12'd667: static_char=8'h2f;
                    12'd668: static_char=8'h6c;
                    12'd669: static_char=8'h5d;
                    12'd671: static_char=8'h4d;
                    12'd672: static_char=8'h4f;
                    12'd673: static_char=8'h56;
                    12'd674: static_char=8'h45;
                    12'd679: static_char=8'h5b;
                    12'd680: static_char=8'h2b;
                    12'd681: static_char=8'h2f;
                    12'd682: static_char=8'h2d;
                    12'd683: static_char=8'h5d;
                    12'd685: static_char=8'h57;
                    12'd686: static_char=8'h49;
                    12'd687: static_char=8'h44;
                    12'd688: static_char=8'h54;
                    12'd689: static_char=8'h48;
                    12'd768: static_char=8'h7c;
                    12'd770: static_char=8'h5b;
                    12'd771: static_char=8'h52;
                    12'd772: static_char=8'h2f;
                    12'd773: static_char=8'h47;
                    12'd774: static_char=8'h2f;
                    12'd775: static_char=8'h55;
                    12'd776: static_char=8'h2f;
                    12'd777: static_char=8'h57;
                    12'd778: static_char=8'h5d;
                    12'd780: static_char=8'h43;
                    12'd781: static_char=8'h4f;
                    12'd782: static_char=8'h4c;
                    12'd783: static_char=8'h4f;
                    12'd784: static_char=8'h52;
                    12'd789: static_char=8'h5b;
                    12'd790: static_char=8'h58;
                    12'd791: static_char=8'h2f;
                    12'd792: static_char=8'h4f;
                    12'd793: static_char=8'h2f;
                    12'd794: static_char=8'h4b;
                    12'd795: static_char=8'h5d;
                    12'd797: static_char=8'h4d;
                    12'd798: static_char=8'h4f;
                    12'd799: static_char=8'h44;
                    12'd800: static_char=8'h45;
                    12'd807: static_char=8'h5b;
                    12'd808: static_char=8'h70;
                    12'd809: static_char=8'h5d;
                    12'd811: static_char=8'h50;
                    12'd812: static_char=8'h41;
                    12'd813: static_char=8'h4e;
                    12'd814: static_char=8'h45;
                    12'd815: static_char=8'h4c;
                    12'd1467: static_char=8'h7c;
                    12'd1469: static_char=8'h50;
                    12'd1470: static_char=8'h69;
                    12'd1471: static_char=8'h4b;
                    12'd1472: static_char=8'h6f;
                    12'd1473: static_char=8'h53;
                    12'd1474: static_char=8'h6f;
                    12'd1475: static_char=8'h4c;
                    12'd1477: static_char=8'h53;
                    12'd1478: static_char=8'h54;
                    12'd1479: static_char=8'h41;
                    12'd1480: static_char=8'h54;
                    12'd1481: static_char=8'h55;
                    12'd1482: static_char=8'h53;
                    12'd1487: static_char=8'h7c;
                    12'd1595: static_char=8'h7c;
                    12'd1597: static_char=8'h43;
                    12'd1598: static_char=8'h50;
                    12'd1599: static_char=8'h55;
                    12'd1604: static_char=8'h3a;
                    12'd1606: static_char=8'h52;
                    12'd1607: static_char=8'h55;
                    12'd1608: static_char=8'h4e;
                    12'd1615: static_char=8'h7c;
                    12'd1723: static_char=8'h7c;
                    12'd1725: static_char=8'h4c;
                    12'd1726: static_char=8'h45;
                    12'd1727: static_char=8'h44;
                    12'd1732: static_char=8'h3a;
                    12'd1734: static_char=8'h30;
                    12'd1735: static_char=8'h78;
                    12'd1743: static_char=8'h7c;
                    12'd1851: static_char=8'h7c;
                    12'd1853: static_char=8'h4f;
                    12'd1854: static_char=8'h42;
                    12'd1855: static_char=8'h4a;
                    12'd1857: static_char=8'h55;
                    12'd1858: static_char=8'h53;
                    12'd1859: static_char=8'h45;
                    12'd1860: static_char=8'h44;
                    12'd1861: static_char=8'h3a;
                    12'd1871: static_char=8'h7c;
                    12'd1979: static_char=8'h7c;
                    12'd1981: static_char=8'h58;
                    12'd1988: static_char=8'h3a;
                    12'd1990: static_char=8'h30;
                    12'd1991: static_char=8'h78;
                    12'd1999: static_char=8'h7c;
                    12'd2107: static_char=8'h7c;
                    12'd2109: static_char=8'h59;
                    12'd2116: static_char=8'h3a;
                    12'd2118: static_char=8'h30;
                    12'd2119: static_char=8'h78;
                    12'd2127: static_char=8'h7c;
                    12'd2235: static_char=8'h7c;
                    12'd2237: static_char=8'h43;
                    12'd2238: static_char=8'h4f;
                    12'd2239: static_char=8'h4c;
                    12'd2240: static_char=8'h4f;
                    12'd2241: static_char=8'h52;
                    12'd2244: static_char=8'h3a;
                    12'd2255: static_char=8'h7c;
                    12'd2363: static_char=8'h7c;
                    12'd2365: static_char=8'h4d;
                    12'd2366: static_char=8'h4f;
                    12'd2367: static_char=8'h44;
                    12'd2368: static_char=8'h45;
                    12'd2372: static_char=8'h3a;
                    12'd2383: static_char=8'h7c;
                    12'd2491: static_char=8'h7c;
                    12'd2493: static_char=8'h55;
                    12'd2494: static_char=8'h41;
                    12'd2495: static_char=8'h52;
                    12'd2496: static_char=8'h54;
                    12'd2500: static_char=8'h3a;
                    12'd2502: static_char=8'h31;
                    12'd2503: static_char=8'h31;
                    12'd2504: static_char=8'h35;
                    12'd2505: static_char=8'h32;
                    12'd2506: static_char=8'h30;
                    12'd2507: static_char=8'h30;
                    12'd2511: static_char=8'h7c;
                    12'd2619: static_char=8'h7c;
                    12'd2621: static_char=8'h47;
                    12'd2622: static_char=8'h52;
                    12'd2623: static_char=8'h41;
                    12'd2624: static_char=8'h50;
                    12'd2625: static_char=8'h48;
                    12'd2626: static_char=8'h49;
                    12'd2627: static_char=8'h43;
                    12'd2628: static_char=8'h53;
                    12'd2629: static_char=8'h3a;
                    12'd2631: static_char=8'h41;
                    12'd2633: static_char=8'h2f;
                    12'd2635: static_char=8'h42;
                    12'd2639: static_char=8'h7c;
                    12'd2747: static_char=8'h7c;
                    12'd2749: static_char=8'h4d;
                    12'd2750: static_char=8'h41;
                    12'd2751: static_char=8'h53;
                    12'd2752: static_char=8'h4b;
                    12'd2756: static_char=8'h3a;
                    12'd2767: static_char=8'h7c;
                    12'd2875: static_char=8'h7c;
                    12'd2877: static_char=8'h4d;
                    12'd2878: static_char=8'h4f;
                    12'd2879: static_char=8'h56;
                    12'd2880: static_char=8'h45;
                    12'd2884: static_char=8'h3a;
                    12'd2886: static_char=8'h69;
                    12'd2888: static_char=8'h6a;
                    12'd2890: static_char=8'h6b;
                    12'd2892: static_char=8'h6c;
                    12'd2895: static_char=8'h7c;
                    12'd3003: static_char=8'h7c;
                    12'd3005: static_char=8'h53;
                    12'd3006: static_char=8'h49;
                    12'd3007: static_char=8'h5a;
                    12'd3008: static_char=8'h45;
                    12'd3012: static_char=8'h3a;
                    12'd3014: static_char=8'h2b;
                    12'd3016: static_char=8'h2f;
                    12'd3018: static_char=8'h2d;
                    12'd3023: static_char=8'h7c;
                    12'd3131: static_char=8'h7c;
                    12'd3133: static_char=8'h50;
                    12'd3134: static_char=8'h41;
                    12'd3135: static_char=8'h4e;
                    12'd3136: static_char=8'h45;
                    12'd3137: static_char=8'h4c;
                    12'd3140: static_char=8'h3a;
                    12'd3142: static_char=8'h70;
                    12'd3151: static_char=8'h7c;
                    12'd3259: static_char=8'h7c;
                    12'd3261: static_char=8'h53;
                    12'd3262: static_char=8'h59;
                    12'd3263: static_char=8'h53;
                    12'd3264: static_char=8'h2f;
                    12'd3265: static_char=8'h50;
                    12'd3266: static_char=8'h49;
                    12'd3267: static_char=8'h58;
                    12'd3268: static_char=8'h3a;
                    12'd3270: static_char=8'h32;
                    12'd3271: static_char=8'h37;
                    12'd3272: static_char=8'h2f;
                    12'd3273: static_char=8'h32;
                    12'd3274: static_char=8'h35;
                    12'd3275: static_char=8'h2e;
                    12'd3276: static_char=8'h32;
                    12'd3279: static_char=8'h7c;
                    default: static_char=8'h20;
                endcase
            end
        end
    endfunction


    reg [7:0] status_char;
    always @* begin
        status_char=static_char(cy,cx);
        if (cy==5'd13 && cx==7'd72) status_char=hexascii({2'b00,shown_led[5:4]});
        if (cy==5'd13 && cx==7'd73) status_char=hexascii(shown_led[3:0]);
        if (cy==5'd14 && cx==7'd71) status_char=shown_sel_b ? 8'h42:8'h41;
        if (cy==5'd15 && cx==7'd72) status_char=hexascii({2'b00,shown_x[9:8]});
        if (cy==5'd15 && cx==7'd73) status_char=hexascii(shown_x[7:4]);
        if (cy==5'd15 && cx==7'd74) status_char=hexascii(shown_x[3:0]);
        if (cy==5'd16 && cx==7'd72) status_char=hexascii({2'b00,shown_y[9:8]});
        if (cy==5'd16 && cx==7'd73) status_char=hexascii(shown_y[7:4]);
        if (cy==5'd16 && cx==7'd74) status_char=hexascii(shown_y[3:0]);
        if (cy==5'd17 && cx==7'd70) status_char=hexascii(shown_color[23:20]);
        if (cy==5'd17 && cx==7'd71) status_char=hexascii(shown_color[19:16]);
        if (cy==5'd17 && cx==7'd72) status_char=hexascii(shown_color[15:12]);
        if (cy==5'd17 && cx==7'd73) status_char=hexascii(shown_color[11:8]);
        if (cy==5'd17 && cx==7'd74) status_char=hexascii(shown_color[7:4]);
        if (cy==5'd17 && cx==7'd75) status_char=hexascii(shown_color[3:0]);
        if (cy==5'd18 && cx==7'd70) status_char=shown_mode[1] ? 8'h4f : (shown_mode[2] ? 8'h4b : 8'h46);
        if (cy==5'd21 && cx==7'd70) status_char=shown_led != 0 ? 8'h31:8'h30;
    end

    wire gfx_log_here=(py>=9'd352 && py<9'd400 && px>=10'd16 && px<10'd624);
    wire term_log_here=(cy>=6'd4 && cy<=6'd32 && cx>=7'd2 && cx<7'd78);
    wire log_here=shell_term ? term_log_here : gfx_log_here;
    wire static_here=(cy<=5'd7) ||
                      (cy>=5'd10 && cy<=5'd26 && cx>=7'd59);
    wire text_here=log_here || (shell_term ? cy<=6'd3 : static_here);
    wire term_backdrop=shell_term && py>=9'd48 && py<9'd400;
    wire [1:0] gfx_yrow=py<9'd364 ? 2'd0 :
                         py<9'd376 ? 2'd1 : py<9'd388 ? 2'd2 : 2'd3;
    wire [3:0] gfx_gy=py<9'd364 ? (py-9'd352) :
                       py<9'd376 ? (py-9'd364) :
                       py<9'd388 ? (py-9'd376) : (py-9'd388);
    wire [4:0] log_phys=wr_row + (shell_term ? (cy-6'd4) : {3'b0,gfx_yrow}) +
                                 (shell_term ? 5'd4 : 5'd29);
    wire [11:0] log_addr=row_base(log_phys)+{5'b0,(cx-7'd2)};
    // Gowin RAM inference: synchronous block ROM, 128 chars * 16 scanlines * 8 pixels.
    // The 8x12 printable ASCII glyphs are copied bit-exact from v0.1.8b.
    // font_mem[char*16 + y] holds a single 8-pixel scanline, NOT 96 muxed bits.
    reg [7:0] font_mem [0:2047] /* synthesis syn_romstyle = "block_rom" */;
    initial $readmemh("lab04_font_8x12.hex", font_mem);

    // Two-stage AXI-style elastic video pipeline.
    // A: capture incoming coordinate, synchronous VRAM read.
    // B: synchronous font ROM read, aligned video data and user marker.
    // Stalls freeze BOTH stages, including the two memory output registers.
    reg a_valid;
    reg [23:0] a_bg;
    reg [0:0] a_user;
    reg [7:0] a_static_char;
    reg [7:0] log_char_a;
    reg [2:0] a_bit;
    reg [3:0] a_gy;
    reg a_text_area, a_log_area, a_heading, a_term_backdrop;

    reg b_valid;
    reg [23:0] b_bg;
    reg [0:0] b_user;
    reg [2:0] b_bit;
    reg b_text_area, b_log_area, b_heading, b_term_backdrop;
    reg [7:0] font_row_b;

    wire b_ready = !b_valid || m_axis_tready;
    wire a_ready = !a_valid || b_ready;
    assign s_axis_tready = a_ready;
    assign m_axis_tvalid = b_valid;
    assign m_axis_tuser = b_user;
    wire [7:0] char_a = a_log_area ? log_char_a : a_static_char;
    wire [10:0] font_addr = {char_a[6:0], a_gy};
    wire ink = font_row_b[7-b_bit];
    assign m_axis_tdata = b_text_area ?
             (ink ? (b_heading ? 24'hD0E878 : b_log_area ? 24'hD8FF90 : 24'hE8E8E8) :
                    b_log_area ? 24'h170f08 : b_heading ? 24'h262018 : 24'h201811) :
              (b_term_backdrop ? 24'h140d08 : b_bg);

    // Read-only port of text VRAM. Separate from the write process above.
    // The memory read itself has no asynchronous reset, allowing BSRAM inference.
    always @(posedge clk_pixel) begin
        if (a_ready && s_axis_tvalid && log_here)
            log_char_a <= log_mem[log_addr];
    end

    // Read-only, synchronous font port. BSRAM output registered here.
    always @(posedge clk_pixel) begin
        if (b_ready && a_valid)
            font_row_b <= font_mem[font_addr];
    end

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            a_valid <= 1'b0;
            a_bg <= 24'd0; a_user <= 1'b0;
            a_static_char <= 8'h20;
            a_bit <= 0; a_gy <= 0;
            a_text_area <= 0; a_log_area <= 0; a_heading <= 0; a_term_backdrop <= 0;
            b_valid <= 1'b0;
            b_bg <= 24'd0; b_user <= 1'b0;
            b_bit <= 0;
            b_text_area <= 0; b_log_area <= 0; b_heading <= 0; b_term_backdrop <= 0;
        end else begin
            if (a_ready) begin
                a_valid <= s_axis_tvalid;
                if (s_axis_tvalid) begin
                    a_bg <= s_axis_tdata;
                    a_user <= s_axis_tuser;
                    a_static_char <= status_char;
                    a_bit <= px[2:0];
                    a_gy <= log_here ? (shell_term ? sy : gfx_gy) : sy;
                    a_text_area <= text_here;
                    a_log_area <= log_here;
                    a_heading <= (cy<=6'd3);
                    a_term_backdrop <= term_backdrop;
                end
            end
            if (b_ready) begin
                b_valid <= a_valid;
                if (a_valid) begin
                    b_bg <= a_bg;
                    b_user <= a_user;
                    b_bit <= a_bit;
                    b_text_area <= a_text_area;
                    b_log_area <= a_log_area;
                    b_heading <= a_heading;
                    b_term_backdrop <= a_term_backdrop;
                end
            end
        end
    end
endmodule
