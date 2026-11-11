// LAB-04.3: independent PicoRV32 SoC, kept separate from LAB-03 files.
// 16 KiB ROM (RV32I) + 1 KiB working RAM at 0x00004000, LED/graphics MMIO, UART.
// Address ABI matches LAB-03 for 0x20000000/10/14/18/1C, but no T3 recorder.
// SPDX-License-Identifier: MIT
module lab04_cpu_soc (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,
    output wire uart_tx,
    output wire [5:0] led_n,
    input wire sd_miso,
    output wire sd_sck, sd_mosi, sd_cs_n,
    output wire [5:0] led_mask_sys, // Uninverted CPU MMIO LED register
    // Blocked MMIO command stream to asynchronous graphics mailbox.
    output wire video_wr_valid,
    input wire video_wr_ready,
    output wire [3:0] video_wr_index,
    output wire [23:0] video_wr_value
);
    wire mem_valid, mem_instr;
    reg mem_ready;
    wire [31:0] mem_addr, mem_wdata;
    wire [3:0] mem_wstrb;
    wire [31:0] mem_rdata;
    wire cpu_trap;

    picorv32 #(
        .PROGADDR_RESET(32'h00000000),
        .COMPRESSED_ISA(0),
        .ENABLE_COUNTERS(1),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0)
    ) u_cpu (
        .clk(clk), .resetn(reset_n), .trap(cpu_trap),
        .mem_valid(mem_valid), .mem_instr(mem_instr), .mem_ready(mem_ready),
        .mem_addr(mem_addr), .mem_wdata(mem_wdata), .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .pcpi_wr(1'b0), .pcpi_rd(32'b0), .pcpi_wait(1'b0), .pcpi_ready(1'b0),
        .irq(32'b0)
    );
    wire is_rom = (mem_addr[31:14] == 18'b0);
    wire is_ram = (mem_addr[31:10] == 22'd16);
    wire is_mmio = (mem_addr[31:8] == 24'h200000);
    wire is_sdmmio = (mem_addr[31:8] == 24'h200002);
    wire sd_access = mem_valid && !mem_ready && is_sdmmio &&
                     (mem_addr[1:0] == 2'b00);
    wire [31:0] sd_rdata;
    sd07_sd_mmio #(.WRITE_FIRST_LBA(32'hFFFFFFFE),
                    .WRITE_LAST_LBA(32'hFFFFFFFE)) u_sd (
       .clk(clk),.reset_n(reset_n),.req_valid(sd_access),
       .req_addr(mem_addr[7:0]),.req_wdata(mem_wdata),
       .req_wstrb(mem_wstrb),.req_rdata(sd_rdata),
       .sd_miso(sd_miso),.sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n));
    wire is_vmmio = (mem_addr[31:8] == 24'h200001);
    wire [3:0] vid_idx = mem_addr[5:2];
    wire vid_idx_valid = (vid_idx <= 4'd5) ||
                         (vid_idx >= 4'd8 && vid_idx <= 4'd13) ||
                         (vid_idx == 4'd15);
    wire vid_word_valid = vid_idx_valid && (mem_addr[7:6] == 2'b0) &&
                           (mem_addr[1:0] == 2'b0);
    // Only full 32-bit stores to known registers generate a pixel event.
    assign video_wr_valid = mem_valid && !mem_ready && is_vmmio &&
                            vid_word_valid && (mem_wstrb == 4'hf);
    assign video_wr_index = vid_idx;
    assign video_wr_value = mem_wdata[23:0];
    reg [23:0] video_shadow [0:15];
    integer vi;
    // BRAM-inferred, synchronous 256x32 scratch RAM for the interactive shell.
    // Only word-aligned full-word stores are currently supported.
    reg [31:0] shell_ram [0:255] /* synthesis syn_ramstyle = "block_ram" */;
    reg [31:0] shell_ram_rdata;
    wire ram_read = mem_valid && !mem_ready && is_ram && !(|mem_wstrb);
    wire ram_write = mem_valid && !mem_ready && is_ram && mem_wstrb == 4'hf;
    always @(posedge clk) begin
        if (ram_read) shell_ram_rdata <= shell_ram[mem_addr[9:2]];
        if (ram_write) shell_ram[mem_addr[9:2]] <= mem_wdata;
    end
    wire [31:0] rom_data;
    lab04_boot_rom u_rom (
        .clk(clk), .word_addr(mem_addr[13:2]), .rdata(rom_data)
    );
    reg return_rom;
    reg return_ram;
    reg [31:0] mmio_rdata;
    assign mem_rdata = return_rom ? rom_data : (return_ram ? shell_ram_rdata : mmio_rdata);

    reg [5:0] leds;
    reg [31:0] cycles;
    reg [31:0] test_status;
    assign led_mask_sys = leds;
    assign led_n = ~leds;  // Real Tang Nano 9K LEDs are active-low.

    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_byte;
    uart_tx_8n1 #(.CLOCK_HZ(27000000), .BAUD(115200)) u_uart_tx (
        .clk(clk), .reset_n(reset_n), .start(tx_start),
        .data(tx_byte), .tx(uart_tx), .busy(tx_busy)
    );
    wire [7:0] rx_byte;
    wire rx_valid, rx_framing_error;
    uart_rx_8n1 #(.CLOCK_HZ(27000000), .BAUD(115200)) u_uart_rx (
        .clk(clk), .reset_n(reset_n), .rx(uart_rx),
        .data(rx_byte), .valid(rx_valid), .framing_error(rx_framing_error)
    );
    reg [7:0] rx_fifo [0:3];
    reg [1:0] rx_wp, rx_rp;
    reg [2:0] rx_count;
    reg rx_overrun, rx_frame_latch;
    wire rx_pop = mem_valid && !mem_ready && is_mmio &&
                  (mem_addr[7:0] == 8'h18) && !(|mem_wstrb) && (rx_count != 0);
    wire rx_push = rx_valid && ((rx_count != 4) || rx_pop);
    wire rx_clear = mem_valid && !mem_ready && is_mmio &&
                    (mem_addr[7:0] == 8'h1c) && (|mem_wstrb);

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mem_ready <= 0;
            return_rom <= 0;
            return_ram <= 0;
            mmio_rdata <= 0;
            leds <= 0;
            cycles <= 0;
            test_status <= 0;
            for (vi=0;vi<16;vi=vi+1) video_shadow[vi] <= 24'b0;
            tx_start <= 0;
            tx_byte <= 0;
            rx_wp <= 0; rx_rp <= 0; rx_count <= 0;
            rx_overrun <= 0; rx_frame_latch <= 0;
        end else begin
            cycles <= cycles + 1'b1;
            mem_ready <= 1'b0;
            tx_start <= 1'b0;
            if (rx_framing_error) rx_frame_latch <= 1;
            if (rx_valid && !rx_push) rx_overrun <= 1;
            if (rx_clear) begin
                rx_overrun <= 0;
                rx_frame_latch <= 0;
            end
            if (rx_push) begin
                rx_fifo[rx_wp] <= rx_byte;
                rx_wp <= rx_wp + 1'b1;
            end
            if (rx_pop) rx_rp <= rx_rp + 1'b1;
            case ({rx_push, rx_pop})
                2'b10: rx_count <= rx_count + 1'b1;
                2'b01: rx_count <= rx_count - 1'b1;
                default: ;
            endcase
            if (mem_valid && !mem_ready) begin
                return_rom <= is_rom;
                return_ram <= is_ram;
                if (is_rom) begin
                    mem_ready <= 1'b1;
                end else if (is_ram) begin
                    if (mem_addr[1:0] != 2'b00 ||
                        ((|mem_wstrb) && mem_wstrb != 4'hf)) begin
                        mmio_rdata <= 32'hBAD0_0020;
                    end else begin
                        mmio_rdata <= 32'b0; // read data uses registered RAM port
                    end
                    mem_ready <= 1'b1;
                end else if (is_sdmmio) begin
                    if(mem_addr[1:0]!=2'b00 ||
                       ((|mem_wstrb) && mem_wstrb!=4'hf))
                        mmio_rdata <= 32'hBAD0_0007;
                    else mmio_rdata <= sd_rdata;
                    mem_ready <= 1'b1;
                end else if (is_vmmio) begin
                    if (!vid_word_valid) begin
                        mmio_rdata <= 32'hBAD0_0017;
                        mem_ready <= 1'b1;
                    end else if (!(|mem_wstrb)) begin
                        mmio_rdata <= {8'd0, video_shadow[vid_idx]};
                        mem_ready <= 1'b1;
                    end else if (mem_wstrb != 4'hf) begin
                        mmio_rdata <= 32'hBAD0_0017;
                        mem_ready <= 1'b1;
                    end else if (video_wr_ready) begin
                        video_shadow[vid_idx] <= mem_wdata[23:0];
                        mmio_rdata <= {8'd0, video_shadow[vid_idx]};
                        mem_ready <= 1'b1;
                    end // Else stall until the CDC mailbox ACKs previous store.
                end else if (is_mmio) begin
                    case (mem_addr[7:0])
                        8'h00: begin
                            if ((|mem_wstrb) && mem_wstrb[0]) leds <= mem_wdata[5:0];
                            mmio_rdata <= {26'b0, leds};
                            mem_ready <= 1;
                        end
                        8'h04: begin mmio_rdata <= cycles; mem_ready <= 1; end
                        8'h08: begin mmio_rdata <= 32'h5A5A0004; mem_ready <= 1; end
                        8'h0c: begin
                            if (|mem_wstrb) test_status <= mem_wdata;
                            mmio_rdata <= test_status;
                            mem_ready <= 1;
                        end
                        8'h10: begin
                            if (!(|mem_wstrb)) begin
                                mmio_rdata <= 0;
                                mem_ready <= 1;
                            end else if (!tx_busy && !tx_start) begin
                                tx_byte <= mem_wdata[7:0];
                                tx_start <= 1;
                                mem_ready <= 1;
                            end
                        end
                        8'h14: begin
                            mmio_rdata <= {31'b0, !(tx_busy || tx_start)};
                            mem_ready <= 1;
                        end
                        8'h18: begin
                            mmio_rdata <= (rx_count != 0) ?
                                {24'b0, rx_fifo[rx_rp]} : 32'b0;
                            mem_ready <= 1;
                        end
                        8'h1c: begin
                            mmio_rdata <= {29'b0, rx_frame_latch, rx_overrun, (rx_count != 0)};
                            mem_ready <= 1;
                        end
                        default: begin
                            mmio_rdata <= 32'hBAD0_0004;
                            mem_ready <= 1;
                        end
                    endcase
                end else begin
                    return_rom <= 0;
                    mmio_rdata <= 32'hBAD0_0002;
                    mem_ready <= 1;
                end
            end
        end
    end
    wire _unused = mem_instr ^ cpu_trap;
endmodule
