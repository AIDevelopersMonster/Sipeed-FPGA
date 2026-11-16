// PR25-06: Tetris game logic and rasterizer for 640x480, 50 MHz.
// Standalone from USB: accepts six USB HID usage codes already synchronized to clk.
// All game state lives in FPGA registers. No CPU, SRAM, SDRAM or framebuffer.
// Keyboard: arrows; fallback known-good keys 1:left 2:rotate 3:right 4:drop 5:down.
// S1 and F1 are managed by the parent lab_top (PASSIVE/HOST and GAME/DIAG).
module tetris_engine #(
    parameter integer CLK_MHZ = 50
)(
    input  wire clk,
    input  wire rst,
    input  wire enable,
    input  wire report_pulse,
    input  wire [7:0] key0, key1, key2, key3, key4, key5,
    input  wire [7:0] modifiers,
    input  wire [9:0] x,
    input  wire [9:0] y,
    output reg  [23:0] rgb,
    output wire [15:0] lines_out,
    output wire [15:0] score_out,
    output wire game_over_out,
    output wire paused_out
);
    localparam [2:0] ST_SPAWN = 3'd0, ST_ACTIVE = 3'd1,
                     ST_HARD  = 3'd2, ST_LOCK   = 3'd3,
                     ST_SCAN  = 3'd4, ST_OVER   = 3'd5;
    localparam integer REPEAT_TICKS = CLK_MHZ * 130000; // 130 ms
    localparam integer FALL_NORMAL = CLK_MHZ * 520000;  // 520 ms
    localparam integer FALL_FAST   = CLK_MHZ *  50000;  //  50 ms

    reg [2:0] phase = ST_SPAWN;
    reg [2:0] piece_type = 3'd0, next_type = 3'd1;
    reg [1:0] rotation = 2'd0;
    reg signed [5:0] piece_x = 6'sd3, piece_y = -6'sd1;
    reg [9:0] board [0:19];           // one occupied bit per cell
    reg [29:0] tile_color [0:19];     // one 3-bit palette index per cell
    reg [4:0] scan_row = 5'd19;
    reg [15:0] score = 16'd0, cleared_lines = 16'd0;
    reg [15:0] rng = 16'hACE1;
    reg paused = 1'b0;
    reg hold_left = 1'b0, hold_right = 1'b0, hold_down = 1'b0;
    reg hold_rotate = 1'b0, hold_drop = 1'b0;
    reg hold_pause = 1'b0, hold_restart = 1'b0;
    reg [22:0] repeat_counter = 23'd0;
    reg [25:0] gravity_counter = 26'd0;

    assign lines_out = cleared_lines;
    assign score_out = score;
    assign paused_out = paused;
    assign game_over_out = phase == ST_OVER;

    function automatic [15:0] piece_base(input [2:0] typ);
        case (typ)
            3'd0: piece_base = 16'h00F0; // I  .... #### .... ....
            3'd1: piece_base = 16'h0660; // O  .##. .##.
            3'd2: piece_base = 16'h0270; // T  ###. .#..
            3'd3: piece_base = 16'h0360; // S  .##. ##..
            3'd4: piece_base = 16'h0630; // Z  ##.. .##.
            3'd5: piece_base = 16'h0170; // J  ###. #...
            default: piece_base = 16'h0470; // L ###. ..#.
        endcase
    endfunction

    function automatic bit piece_cell(
        input [2:0] typ, input [1:0] rot, input integer lx, ly
    );
        reg [15:0] base;
        integer bx, by;
        begin
            piece_cell = 1'b0;
            if (lx >= 0 && lx < 4 && ly >= 0 && ly < 4) begin
                base = piece_base(typ);
                if (typ == 3'd1) begin // O piece never shifts while rotating
                    bx = lx; by = ly;
                end else begin
                    case (rot)
                        2'd0: begin bx=lx;     by=ly;     end
                        2'd1: begin bx=ly;     by=3-lx;   end
                        2'd2: begin bx=3-lx;   by=3-ly;   end
                        default: begin bx=3-ly; by=lx;    end
                    endcase
                end
                piece_cell = base[by*4 + bx];
            end
        end
    endfunction

    // Collision uses at most FOUR 10-bit board-row reads per candidate.
    // This is much cheaper than 16 independent dynamic bit-selects per trial.
    function automatic bit can_place(
        input [2:0] typ, input [1:0] rot,
        input integer xpos, ypos
    );
        integer a, b, cx, cy;
        reg [3:0] shape_row;
        reg [9:0] row_overlap;
        begin
            can_place = 1'b1;
            for (b=0; b<4; b=b+1) begin
                shape_row = 4'b0000;
                for (a=0; a<4; a=a+1)
                    shape_row[a] = piece_cell(typ,rot,a,b);
                if (shape_row != 0) begin
                    cy = ypos+b;
                    if (cy>=20) can_place = 1'b0;
                    for (a=0; a<4; a=a+1) begin
                        cx = xpos+a;
                        if (shape_row[a] && (cx<0 || cx>=10))
                            can_place = 1'b0;
                    end
                    if (cy >= 0 && cy < 20) begin
                        if (xpos>=0)
                            row_overlap = {6'b0,shape_row} << xpos;
                        else
                            row_overlap = {6'b0,shape_row} >> (-xpos);
                        if ((board[cy] & row_overlap) != 10'b0)
                            can_place = 1'b0;
                    end
                end
            end
        end
    endfunction

    function automatic bit contains(input [7:0] code);
        contains = key0==code || key1==code || key2==code ||
                   key3==code || key4==code || key5==code;
    endfunction
    wire k_left    = contains(8'h50) || contains(8'h04) || contains(8'h1E); // arrow/A/1
    wire k_right   = contains(8'h4F) || contains(8'h07) || contains(8'h20); // arrow/D/3
    wire k_rotate  = contains(8'h52) || contains(8'h1A) || contains(8'h1F); // up/W/2
    wire k_down    = contains(8'h51) || contains(8'h16) || contains(8'h22); // down/S/5
    wire k_drop    = contains(8'h2C) || contains(8'h21); // SPACE / 4
    wire k_pause   = contains(8'h13); // P
    wire k_restart = contains(8'h15); // R
    wire ev_left    = report_pulse && k_left    && !hold_left;
    wire ev_right   = report_pulse && k_right   && !hold_right;
    wire ev_rotate  = report_pulse && k_rotate  && !hold_rotate;
    wire ev_drop    = report_pulse && k_drop    && !hold_drop;
    wire ev_pause   = report_pulse && k_pause   && !hold_pause;
    wire ev_restart = report_pulse && k_restart && !hold_restart;
    wire repeat_due = repeat_counter == REPEAT_TICKS-1;
    wire gravity_due = gravity_counter >= (hold_down ? FALL_FAST-1 : FALL_NORMAL-1);

    integer row, col, ax, ay;
    reg has_above;
    always @(posedge clk or posedge rst) begin
        if (rst || (enable && ev_restart)) begin
            for (row=0; row<20; row=row+1) begin
                board[row] <= 10'd0;
                tile_color[row] <= 30'd0;
            end
            phase <= ST_SPAWN;
            piece_type <= 3'd0; next_type <= 3'd1;
            rotation <= 2'd0;
            piece_x <= 6'sd3; piece_y <= -6'sd1;
            rng <= 16'hACE1;
            score <= 16'd0; cleared_lines <= 16'd0;
            scan_row <= 5'd19;
            paused <= 1'b0;
            hold_left <= 0; hold_right <= 0; hold_down <= 0;
            hold_rotate <= 0; hold_drop <= 0;
            hold_pause <= 0; hold_restart <= 0;
            repeat_counter <= 0; gravity_counter <= 0;
        end else begin
            if (!enable) begin
                hold_left <= 0; hold_right <= 0; hold_down <= 0;
                hold_rotate <= 0; hold_drop <= 0;
                hold_pause <= 0; hold_restart <= 0;
                repeat_counter <= 0;
            end else if (report_pulse) begin
                hold_left <= k_left;
                hold_right <= k_right;
                hold_down <= k_down;
                hold_rotate <= k_rotate;
                hold_drop <= k_drop;
                hold_pause <= k_pause;
                hold_restart <= k_restart;
            end

            if (enable && ev_pause) paused <= ~paused;

            if (!enable || paused || phase != ST_ACTIVE) begin
                repeat_counter <= 0;
                gravity_counter <= 0;
            end else begin
                if (hold_left ^ hold_right) begin
                    if (repeat_due) repeat_counter <= 0;
                    else repeat_counter <= repeat_counter + 1'b1;
                end else repeat_counter <= 0;
                if (gravity_due) gravity_counter <= 0;
                else gravity_counter <= gravity_counter + 1'b1;
            end

            // Synchronous game phases: no dynamic clocks or large frame buffer.
            if (enable && !paused && !ev_pause) begin
                case (phase)
                    ST_SPAWN: begin
                        piece_type <= next_type;
                        next_type <= (rng[2:0] == 3'd7) ? 3'd0 : rng[2:0];
                        rng <= {rng[14:0],rng[15]^rng[13]^rng[12]^rng[10]};
                        rotation <= 2'd0;
                        piece_x <= 6'sd3; piece_y <= -6'sd1;
                        if (can_place(next_type,2'd0,3,-1)) phase <= ST_ACTIVE;
                        else phase <= ST_OVER;
                    end
                    ST_ACTIVE: begin
                        if (ev_drop) phase <= ST_HARD;
                        else if (ev_rotate) begin
                            if (can_place(piece_type,rotation+2'd1,piece_x,piece_y))
                                rotation <= rotation + 2'd1;
                            else if (can_place(piece_type,rotation+2'd1,piece_x-1,piece_y)) begin
                                rotation <= rotation + 2'd1; piece_x <= piece_x - 6'sd1;
                            end else if (can_place(piece_type,rotation+2'd1,piece_x+1,piece_y)) begin
                                rotation <= rotation + 2'd1; piece_x <= piece_x + 6'sd1;
                            end
                        end else if ((ev_left || (repeat_due && hold_left && !hold_right)) &&
                                     can_place(piece_type,rotation,piece_x-1,piece_y))
                            piece_x <= piece_x - 6'sd1;
                        else if ((ev_right || (repeat_due && hold_right && !hold_left)) &&
                                      can_place(piece_type,rotation,piece_x+1,piece_y))
                            piece_x <= piece_x + 6'sd1;
                        else if (gravity_due) begin
                            if (can_place(piece_type,rotation,piece_x,piece_y+1))
                                piece_y <= piece_y + 6'sd1;
                            else phase <= ST_LOCK;
                        end
                    end
                    ST_HARD: begin
                        // One row every 50 MHz clock; bounded by 20 rows.
                        if (can_place(piece_type,rotation,piece_x,piece_y+1))
                            piece_y <= piece_y + 6'sd1;
                        else phase <= ST_LOCK;
                    end
                    ST_LOCK: begin
                        has_above = 1'b0;
                        for (row=0; row<4; row=row+1) begin
                            for (col=0; col<4; col=col+1) begin
                                if (piece_cell(piece_type,rotation,col,row)) begin
                                    ax = piece_x + col;
                                    ay = piece_y + row;
                                    if (ay < 0) has_above = 1'b1;
                                    else if (ax>=0 && ax<10 && ay<20) begin
                                        board[ay][ax] <= 1'b1;
                                        tile_color[ay][ax*3 +: 3] <= piece_type + 3'd1;
                                    end
                                end
                            end
                        end
                        scan_row <= 5'd19;
                        phase <= has_above ? ST_OVER : ST_SCAN;
                    end
                    ST_SCAN: begin
                        if (&board[scan_row]) begin
                            // Shift everything above the full row down one row.
                            for (row=0; row<20; row=row+1) begin
                                if (row == 0) begin
                                    board[0] <= 10'd0;
                                    tile_color[0] <= 30'd0;
                                end else if (row <= scan_row) begin
                                    board[row] <= board[row-1];
                                    tile_color[row] <= tile_color[row-1];
                                end
                            end
                            score <= score + 16'd100;
                            cleared_lines <= cleared_lines + 16'd1;
                            // Keep same scan_row; another full row may have moved here.
                        end else if (scan_row == 0) phase <= ST_SPAWN;
                        else scan_row <= scan_row - 5'd1;
                    end
                    ST_OVER: begin
                        // R restarts via ev_restart handled above.
                    end
                    default: phase <= ST_SPAWN;
                endcase
            end
        end
    end

    function automatic [23:0] palette(input [2:0] c);
        case (c)
            3'd1: palette=24'h45D8ED; // cyan I
            3'd2: palette=24'hF3D568; // yellow O
            3'd3: palette=24'hAF7CF2; // violet T
            3'd4: palette=24'h67D78B; // green S
            3'd5: palette=24'hEE7483; // red Z
            3'd6: palette=24'h6C97F4; // blue J
            3'd7: palette=24'hECA466; // orange L
            default: palette=24'h223648;
        endcase
    endfunction

    function automatic [6:0] segments(input [3:0] digit);
        case(digit)
            4'h0: segments=7'b1111110;
            4'h1: segments=7'b0110000;
            4'h2: segments=7'b1101101;
            4'h3: segments=7'b1111001;
            4'h4: segments=7'b0110011;
            4'h5: segments=7'b1011011;
            4'h6: segments=7'b1011111;
            4'h7: segments=7'b1110000;
            4'h8: segments=7'b1111111;
            4'h9: segments=7'b1111011;
            4'hA: segments=7'b1110111;
            4'hB: segments=7'b0011111;
            4'hC: segments=7'b1001110;
            4'hD: segments=7'b0111101;
            4'hE: segments=7'b1001111;
            default: segments=7'b1000111;
        endcase
    endfunction
    function automatic bit digit48(input [3:0] d, input integer ox,oy,
                                   input [9:0] px,py);
        reg [6:0] s;
        integer dx,dy;
        begin
            digit48=0;
            dx = px-ox; dy = py-oy;
            if (dx>=0 && dx<48 && dy>=0 && dy<72) begin
                s=segments(d);
                digit48=(s[6] && dy<7 && dx>=7 && dx<41) ||
                        (s[5] && dx>=41 && dy>=7 && dy<35) ||
                        (s[4] && dx>=41 && dy>=37 && dy<65) ||
                        (s[3] && dy>=65 && dx>=7 && dx<41) ||
                        (s[2] && dx<7 && dy>=37 && dy<65) ||
                        (s[1] && dx<7 && dy>=7 && dy<35) ||
                        (s[0] && dy>=33 && dy<40 && dx>=7 && dx<41);
            end
        end
    endfunction
    function automatic bit digit24(input [3:0] d, input integer ox,oy,
                                   input [9:0] px,py);
        reg [6:0] s;
        integer dx,dy;
        begin
            digit24=0;
            dx=px-ox; dy=py-oy;
            if (dx>=0 && dx<24 && dy>=0 && dy<36) begin
                s=segments(d);
                digit24=(s[6] && dy<4 && dx>=4 && dx<20) ||
                        (s[5] && dx>=20 && dy>=4 && dy<17) ||
                        (s[4] && dx>=20 && dy>=19 && dy<33) ||
                        (s[3] && dy>=33 && dx>=4 && dx<20) ||
                        (s[2] && dx<4 && dy>=19 && dy<33) ||
                        (s[1] && dx<4 && dy>=4 && dy<17) ||
                        (s[0] && dy>=16 && dy<20 && dx>=4 && dx<20);
            end
        end
    endfunction

    // 5x7 alphabet is generated below from a small, immutable bitmap table.
    function automatic [34:0] letter5(input [7:0] ch);
        begin
            case(ch)
                                8'h20: letter5=35'h000000000;
                8'h31: letter5=35'h11842108E;
                8'h41: letter5=35'h3A31FC631;
                8'h42: letter5=35'h7A31F463E;
                8'h43: letter5=35'h3E108420F;
                8'h44: letter5=35'h7A318C63E;
                8'h45: letter5=35'h7E10F421F;
                8'h46: letter5=35'h7E10F4210;
                8'h47: letter5=35'h3E10BC62E;
                8'h48: letter5=35'h4631FC631;
                8'h49: letter5=35'h7C842109F;
                8'h4B: letter5=35'h4654C5251;
                8'h4C: letter5=35'h42108421F;
                8'h4D: letter5=35'h4775AC631;
                8'h4E: letter5=35'h47359C631;
                8'h4F: letter5=35'h3A318C62E;
                8'h50: letter5=35'h7A31F4210;
                8'h52: letter5=35'h7A31F5251;
                8'h53: letter5=35'h3E107043E;
                8'h54: letter5=35'h7C8421084;
                8'h55: letter5=35'h46318C62E;
                8'h56: letter5=35'h46318C544;
                8'h59: letter5=35'h462A21084;
                default: letter5=35'd0;
            endcase
        end
    endfunction
    function automatic bit glyph_on(input [7:0] ch,
                                    input integer ox,oy,input [9:0] px,py);
        reg [34:0] p;
        integer dx,dy,cx,cy;
        begin
            glyph_on=0;
            dx=px-ox; dy=py-oy;
            if (dx>=0 && dx<10 && dy>=0 && dy<14) begin
                cx=dx>>1; cy=dy>>1;
                p=letter5(ch);
                glyph_on=p[(6-cy)*5+(4-cx)];
            end
        end
    endfunction

    // For tiny fonts each letter occupies 16x14 px; constants synthesize to simple LUTs.
    wire label_title = glyph_on(8'h54,86,18,x,y) ||
        glyph_on(8'h45,102,18,x,y) ||
        glyph_on(8'h54,118,18,x,y) ||
        glyph_on(8'h52,134,18,x,y) ||
        glyph_on(8'h49,150,18,x,y) ||
        glyph_on(8'h53,166,18,x,y);
    wire label_score = glyph_on(8'h53,335,71,x,y) ||
        glyph_on(8'h43,351,71,x,y) ||
        glyph_on(8'h4F,367,71,x,y) ||
        glyph_on(8'h52,383,71,x,y) ||
        glyph_on(8'h45,399,71,x,y);
    wire label_lines = glyph_on(8'h4C,335,194,x,y) ||
        glyph_on(8'h49,351,194,x,y) ||
        glyph_on(8'h4E,367,194,x,y) ||
        glyph_on(8'h45,383,194,x,y) ||
        glyph_on(8'h53,399,194,x,y);
    wire label_next  = glyph_on(8'h4E,335,313,x,y) ||
        glyph_on(8'h45,351,313,x,y) ||
        glyph_on(8'h58,367,313,x,y) ||
        glyph_on(8'h54,383,313,x,y);
    wire label_key   = glyph_on(8'h4B,340,425,x,y) ||
        glyph_on(8'h45,356,425,x,y) ||
        glyph_on(8'h59,372,425,x,y);
    wire label_mod   = glyph_on(8'h4D,495,425,x,y) ||
        glyph_on(8'h4F,511,425,x,y) ||
        glyph_on(8'h44,527,425,x,y);
    wire label_over  = glyph_on(8'h4F,365,309,x,y) ||
        glyph_on(8'h56,381,309,x,y) ||
        glyph_on(8'h45,397,309,x,y) ||
        glyph_on(8'h52,413,309,x,y);
    wire label_pause = glyph_on(8'h50,356,283,x,y) ||
        glyph_on(8'h41,372,283,x,y) ||
        glyph_on(8'h55,388,283,x,y) ||
        glyph_on(8'h53,404,283,x,y) ||
        glyph_on(8'h45,420,283,x,y);
    wire label_diag  = glyph_on(8'h46,482,19,x,y) ||
        glyph_on(8'h31,498,19,x,y) ||
        glyph_on(8'h44,530,19,x,y) ||
        glyph_on(8'h49,546,19,x,y) ||
        glyph_on(8'h41,562,19,x,y) ||
        glyph_on(8'h47,578,19,x,y);

    wire inside = x>=10'd86 && x<10'd246 && y>=10'd74 && y<10'd394;
    wire [3:0] col_pix = (x-10'd86)>>4;
    wire [4:0] row_pix = (y-10'd74)>>4;
    wire [3:0] dx_pix=(x-10'd86)&10'h00f;
    wire [3:0] dy_pix=(y-10'd74)&10'h00f;
    wire [2:0] fixed_palette = inside ? tile_color[row_pix][col_pix*3 +: 3] : 3'd0;
    wire fixed_cell = inside ? board[row_pix][col_pix] : 1'b0;
    wire moving_cell = inside && (phase==ST_ACTIVE || phase==ST_HARD) &&
        piece_cell(piece_type,rotation,
            $signed({1'b0,col_pix})-$signed(piece_x),
            $signed({1'b0,row_pix})-$signed(piece_y));
    wire [2:0] display_color = moving_cell ? piece_type+3'd1 : fixed_palette;
    wire cell_border = dx_pix==0 || dy_pix==0 || dx_pix==15 || dy_pix==15;

    wire preview = x>=10'd360 && x<10'd424 && y>=10'd340 && y<10'd404;
    wire [2:0] nx = (x-10'd360)>>4, ny=(y-10'd340)>>4;
    wire [3:0] nxd=(x-10'd360)&10'hf, nyd=(y-10'd340)&10'hf;
    wire preview_cell=preview && piece_cell(next_type,2'd0,nx,ny);

    wire score_on =
        digit48(score[15:12],341,102,x,y) ||
        digit48(score[11:8], 402,102,x,y) ||
        digit48(score[7:4],  463,102,x,y) ||
        digit48(score[3:0],  524,102,x,y);
    wire lines_on =
        digit48(cleared_lines[7:4],353,215,x,y) ||
        digit48(cleared_lines[3:0],414,215,x,y);
    wire key_on =
        digit24(key0[7:4],394,433,x,y) ||
        digit24(key0[3:0],425,433,x,y);
    wire mod_on =
        digit24(modifiers[7:4],543,433,x,y) ||
        digit24(modifiers[3:0],573,433,x,y);

    always @(*) begin
        rgb=24'h081727;
        if (y<10'd48) rgb=24'h173B61;
        if (x>=10'd70 && x<10'd265 && y>=10'd57 && y<10'd408)
            rgb=24'h29485D;
        if (x>=10'd78 && x<10'd254 && y>=10'd66 && y<10'd402)
            rgb=24'h102234;
        if (inside) begin
            rgb=24'h0F2538;
            if (fixed_cell || moving_cell)
                rgb=cell_border ? 24'h1D4057 : palette(display_color);
            else if (cell_border) rgb=24'h19334A;
        end
        if (x>=10'd322 && x<10'd614 && y>=10'd61 && y<10'd186) rgb=24'h173547;
        if (x>=10'd322 && x<10'd614 && y>=10'd192 && y<10'd300) rgb=24'h173547;
        if (x>=10'd322 && x<10'd614 && y>=10'd305 && y<10'd412) rgb=24'h173547;
        if (preview) begin
            rgb=24'h162A3D;
            if (preview_cell)
                rgb=(nxd==0 || nyd==0 || nxd==15 || nyd==15)?24'h1D4057:palette(next_type+3'd1);
        end
        if (score_on) rgb=24'hF5DA83;
        if (lines_on) rgb=24'h8CF2C5;
        if (x>=10'd315 && x<10'd629 && y>=10'd415) rgb=24'h213C52;
        if (key_on) rgb=24'h6DE3EF;
        if (mod_on) rgb=24'hE5B66A;
        if (label_title || label_score || label_lines || label_next || label_key || label_mod || label_diag)
            rgb=24'hE5F1FA;
        if (phase == ST_OVER && x>=10'd280 && x<10'd624 && y>=10'd304 && y<10'd330)
            rgb=24'h83384A;
        if (phase == ST_OVER && label_over) rgb=24'hFFFFFF;
        if (paused && x>=10'd277 && x<10'd627 && y>=10'd278 && y<10'd302)
            rgb=24'h8A6C2B;
        if (paused && label_pause) rgb=24'hFFF2BA;
        if (x>=640 || y>=480) rgb=24'h000000;
    end
endmodule
