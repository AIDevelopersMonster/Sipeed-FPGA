// PiKoSoL 25K CPU01. Test SoC with REAL PicoRV32 RV32I execution.
// Board USB HID/DVI hard interface is inherited from tested Console02.
// CPU clock = 50 MHz board oscillator. RAM video port has independent read.
// UART/SDRAM/FPGA Flash are not involved.
//
// Address map:
//   0x00000000 .. 0x000001ff  read-only boot ROM, 128x32 words
//   0x10000000 .. 0x100005ff  write-only text VRAM, 384x8 characters
//   0x10001000               read-only HID usage code (low byte)
// Character cells: video x 64..575, y 336..431, 64x6 cells (8x16).
module pikosol_rv32i_soc (
    input wire clk, rst,
    input wire [7:0] hid_code,
    input wire [9:0] x, y,
    output wire pixel_valid,
    output reg [23:0] pixel_rgb
);
    wire mem_valid, mem_instr;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    reg mem_ready=0;
    reg [31:0] mem_rdata=0;
    wire trap;

    // FPGA configuration leaves the external board reset inactive. PicoRV32
    // must receive an explicit asserted reset for several CPU clocks.
    // This shift register initializes to zero at configuration and releases
    // reset only after 8 consecutive clocks. External rst re-arms it.
    reg [7:0] cpu_reset_pipe = 8'h00;
    always @(posedge clk or posedge rst) begin
        if (rst) cpu_reset_pipe <= 8'h00;
        else cpu_reset_pipe <= {cpu_reset_pipe[6:0], 1'b1};
    end
    wire cpu_resetn = cpu_reset_pipe[7] && !rst;

    picorv32 #(
        .ENABLE_COUNTERS(0),
        .ENABLE_COUNTERS64(0),
        .ENABLE_REGS_16_31(1),
        .TWO_STAGE_SHIFT(0),
        .BARREL_SHIFTER(0),
        .PROGADDR_RESET(32'h00000000)
    ) cpu (
        .clk(clk), .resetn(cpu_resetn),
        .trap(trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr),
        .mem_ready(mem_ready), .mem_addr(mem_addr),
        .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .irq(32'b0)
    );

    // Immutable boot program generated from cpu_boot_listing.S.
    // readmemh file placed into Gowin work directory by Build script.
    (* syn_ramstyle = "block_ram" *)
    reg [31:0] boot_rom [0:127];
    initial $readmemh("cpu_boot.mem", boot_rom);

    // One MMIO request is acknowledged in the NEXT cycle.
    // The PicoRV32 memory interface keeps the address/data stable until
    // the acknowledgment. No second write while mem_ready=1.
    wire rom_select = (mem_addr[31:9] == 23'd0);
    wire video_select = (mem_addr[31:11] == 21'h20000) &&
                        (mem_addr[10:2] < 9'd384);
    wire keyboard_select = (mem_addr == 32'h10001000);

    // CPU01 board diagnosis: latching actual bus events, not static UI.
    reg seen_fetch=1'b0;
    reg seen_write=1'b0;
    reg seen_keyboard=1'b0;
    reg seen_trap=1'b0;
    reg [7:0] rom_count=0;
    reg [7:0] write_count=0;
    reg [31:0] last_rom_pc=0;
    reg [31:0] last_rom_op=0;
    reg [31:0] last_ack_data=0;
    reg [7:0] ack_count=0;
    reg seen_ack=0;
    always @(posedge clk) begin
        if (!cpu_resetn) begin
            seen_fetch<=0;
            seen_write<=0;
            seen_keyboard<=0;
            seen_trap<=0;
            rom_count<=0;
            write_count<=0;
            last_rom_pc<=0;
            last_rom_op<=0;
            last_ack_data<=0;
            ack_count<=0;
            seen_ack<=0;
        end else begin
            if (mem_valid && mem_ready && mem_instr) begin
                seen_ack<=1;
                last_ack_data<=mem_rdata;
                if (ack_count!=8'hff) ack_count<=ack_count+8'd1;
            end
            if (mem_valid && !mem_ready && rom_select && mem_wstrb==0) begin
                seen_fetch<=1;
                last_rom_pc<=mem_addr;
                last_rom_op<=boot_rom[mem_addr[8:2]];
                if (rom_count != 8'hff) rom_count<=rom_count+1'b1;
            end
            if (mem_valid && !mem_ready && video_select && (|mem_wstrb)) begin
                seen_write<=1;
                if (write_count != 8'hff) write_count<=write_count+1'b1;
            end
            if (mem_valid && !mem_ready && keyboard_select)
                seen_keyboard<=1;
            if (trap) seen_trap<=1;
        end
    end

    // 64x6 character buffer uses one CPU write port and a synchronous
    // pixel read port. No reset of the entire array (CPU clears at boot).
    (* syn_ramstyle = "block_ram" *)
    reg [7:0] text_vram [0:383];
    wire video_write = mem_valid && !mem_ready &&
                       video_select && (|mem_wstrb);
    wire [8:0] video_word_addr=mem_addr[10:2];
    wire [7:0] new_char = mem_wstrb[0] ? mem_wdata[7:0] :
                          mem_wstrb[1] ? mem_wdata[15:8] :
                          mem_wstrb[2] ? mem_wdata[23:16] :
                                         mem_wdata[31:24];

    always @(posedge clk) begin
        if (!cpu_resetn) begin
            mem_ready <= 1'b0;
            mem_rdata <= 32'd0;
        end else begin
            mem_ready <= mem_valid && !mem_ready;
            if (mem_valid && !mem_ready) begin
                if (rom_select)
                    mem_rdata <= boot_rom[mem_addr[8:2]];
                else if (keyboard_select)
                    mem_rdata <= {24'd0,hid_code};
                else
                    mem_rdata <= 32'd0;
            end
        end
    end

    assign pixel_valid = (x>=10'd64 && x<10'd576 &&
                          y>=10'd240 && y<10'd432);

    wire [9:0] local_x=x-10'd64, local_y=y-10'd336;
    wire [5:0] cell_col=local_x[8:3];
    wire [2:0] cell_row=local_y[6:4];
    wire [8:0] video_read_addr={cell_row,6'd0}+{3'd0,cell_col};
    reg [7:0] read_char=8'h20;
    reg [2:0] sub_x=0;
    reg [3:0] sub_y=0;
    reg active_d=0;
    always @(posedge clk) begin
        if (video_write) text_vram[video_word_addr] <= new_char;
        if (pixel_valid)
            read_char <= text_vram[video_read_addr];
        else
            read_char <= 8'h20;
        sub_x<=local_x[2:0];
        sub_y<=local_y[3:0];
        active_d<=pixel_valid;
    end
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
    // Three independent yellow debug HEX rows:
    // y 240: data actually handed to CPU at an instruction ACK
    // y 272: last requested ROM PC
    // y 288: ROM word at that PC
    function automatic [7:0] hex_ascii(input [3:0] nib);
        begin
            hex_ascii=(nib<4'd10) ? (8'h30+nib) : (8'h41+nib-4'd10);
        end
    endfunction
    wire [9:0] dbg_x=x-10'd64;
    wire [9:0] dbg_y=y-10'd272;
    wire [2:0] dbg_digit=dbg_x[5:3];
    wire [4:0] dbg_shift=5'd28-{dbg_digit,2'b00};
    wire [31:0] dbg_val= (y>=10'd240 && y<10'd256) ? last_ack_data :
                         (y>=10'd272 && y<10'd288) ? last_rom_pc :
                         last_rom_op;
    wire [31:0] dbg_word=dbg_val >> dbg_shift;
    wire [7:0] dbg_ascii=hex_ascii(dbg_word[3:0]);
    wire [34:0] dbg_bitmap=glyph(dbg_ascii);
    reg [34:0] glyph_bits;
    reg dot;
    integer gi;
    always @* begin
        glyph_bits=glyph(read_char);
        gi=0;
        dot=0;
        if (sub_x<3'd5 && sub_y>=4'd1 && sub_y<=4'd14) begin
            gi=(6-((sub_y-4'd1)>>1))*5+(4-sub_x);
            dot=glyph_bits[gi];
        end
        pixel_rgb=24'h102738;
        if (dot && active_d && y>=10'd336) pixel_rgb=24'h89EFBD;
        // Each digit is an 8x16 cell, values are actual latched bus state.
        if (x>=10'd64 && x<10'd128 &&
            ((y>=10'd240 && y<10'd256) ||
             (y>=10'd272 && y<10'd304)) &&
            dbg_x[2:0]<3'd5 && dbg_y[3:0]>=4'd1 && dbg_y[3:0]<=4'd14) begin
            gi=(6-((dbg_y[3:0]-4'd1)>>1))*5+(4-dbg_x[2:0]);
            if (dbg_bitmap[gi]) pixel_rgb=24'hFFE28B;
        end

        // Cyan/yellow small ACK indicator, independent of instruction text.
        if (y>=10'd260 && y<10'd268 && x>=10'd64 && x<10'd128)
            pixel_rgb=seen_ack ? 24'h00EEAA : 24'hAC3434;

        // Thin blue boot-reset flag: becomes CYAN once reset has released.
        // Blue forever means the CPU is held in reset or its clock is missing.
        if (y>=10'd312 && y<10'd316 && x>=10'd64 && x<10'd576)
            pixel_rgb=cpu_resetn ? 24'h00DDEE : 24'h004488;

        // Non-text CPU diagnostic strip at y=316..331, read left to right:
        // 1 ROM0 is exact expected first instruction 0x100000b7
        // 2 CPU fetch at least one ROM instruction
        // 3 CPU performed a video MMIO write
        // 4 CPU reads the HID keyboard register
        // 5 CPU trap observed (RED = trap)
        // These are hardware event latches, not CPU-generated characters.
        if (y>=10'd316 && y<10'd332) begin
            pixel_rgb=24'h0C0C0C;
            if (x>=10'd64 && x<10'd152)
                pixel_rgb=(boot_rom[0]==32'h100000b7) ? 24'h22D377 : 24'hB82737;
            else if (x>=10'd168 && x<10'd256)
                pixel_rgb=seen_fetch ? 24'h22D377 : 24'hB82737;
            else if (x>=10'd272 && x<10'd360)
                pixel_rgb=seen_write ? 24'h22D377 : 24'hB82737;
            else if (x>=10'd376 && x<10'd464)
                pixel_rgb=seen_keyboard ? 24'h22D377 : 24'hB82737;
            else if (x>=10'd480 && x<10'd568)
                pixel_rgb=seen_trap ? 24'hE92828 : 24'h22D377;
        end
    end
endmodule
