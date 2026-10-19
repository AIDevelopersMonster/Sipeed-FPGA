// Sipeed-FPGA, 01-PicoRV32, Stage P1 (boot demonstrator)
// SPDX-License-Identifier: MIT
// Board: Tang Nano 9K (27 MHz). No vendor-specific FPGA primitives.
// Upstream CPU is fetched separately; not vendored in this repository.
module picorv32_soc (
    input wire clk,
    input wire reset_n,
    input wire uart_rx,  // Reserved for stage P2 (RX console).
    output wire uart_tx,
    output wire [5:0] led_n
);
    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;
    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;
    wire [31:0] mem_rdata;
    wire        cpu_trap;

    // Reference design uses a plain RV32I core. No custom IRQ/PCPI ISA.
    picorv32 #(
        .PROGADDR_RESET(32'h00000000),
        .COMPRESSED_ISA(0),
        .ENABLE_COUNTERS(1),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .ENABLE_IRQ(0)
    ) cpu (
        .clk(clk),
        .resetn(reset_n),
        .trap(cpu_trap),
        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),
        .mem_rdata(mem_rdata),
        .pcpi_wr(1'b0),
        .pcpi_rd(32'b0),
        .pcpi_wait(1'b0),
        .pcpi_ready(1'b0),
        .irq(32'b0)
    );

    // Native PicoRV32 memory bus (word address within boot ROM).
    wire is_boot = (mem_addr[31:10] == 22'b0);
    wire is_mmio = (mem_addr[31:8] == 24'h200000);
    wire [31:0] rom_data;
    boot_rom u_rom (
        .clk(clk),
        .word_addr(mem_addr[9:2]),
        .rdata(rom_data)
    );

    reg return_rom;
    reg [31:0] mmio_rdata;
    assign mem_rdata = return_rom ? rom_data : mmio_rdata;

    reg [5:0] leds;
    reg [31:0] cycles;
    reg [31:0] test_status;
    assign led_n = ~leds;  // Tang Nano 9K onboard LEDs are active-low.

    wire tx_busy;
    reg tx_start;
    reg [7:0] tx_byte;
    uart_tx_8n1 #(.CLOCK_HZ(27_000_000), .BAUD(115200)) u_uart (
        .clk(clk), .reset_n(reset_n), .start(tx_start), .data(tx_byte),
        .tx(uart_tx), .busy(tx_busy)
    );

    // Common register contract (word accesses):
    // 0x20000000 LED[5:0] R/W
    // 0x20000004 free-running CYCLES R/O
    // 0x20000008 DEVICE_ID = 0x5A5A0001 R/O
    // 0x2000000C TEST_STATUS R/W (firmware writes 0x600DCAFE)
    // 0x20000010 UART_TX W/O (byte in low 8 bits; stalls if busy)
    // 0x20000014 UART_STATUS R/O (bit 0 = ready)
    // Unmapped accesses terminate with diagnostic read data; not an exception.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            mem_ready   <= 1'b0;
            return_rom  <= 1'b0;
            mmio_rdata  <= 32'b0;
            leds        <= 6'b0;
            cycles      <= 32'b0;
            test_status <= 32'b0;
            tx_start    <= 1'b0;
            tx_byte     <= 8'b0;
        end else begin
            cycles    <= cycles + 1'b1;
            mem_ready <= 1'b0;
            tx_start  <= 1'b0;
            if (mem_valid && !mem_ready) begin
                return_rom <= is_boot;
                if (is_boot) begin
                    mem_ready <= 1'b1;
                end else if (is_mmio) begin
                    case (mem_addr[7:0])
                        8'h00: begin
                            if (|mem_wstrb && mem_wstrb[0]) leds <= mem_wdata[5:0];
                            mmio_rdata <= {26'b0, leds};
                            mem_ready <= 1'b1;
                        end
                        8'h04: begin
                            mmio_rdata <= cycles;
                            mem_ready <= 1'b1;
                        end
                        8'h08: begin
                            mmio_rdata <= 32'h5A5A0001;
                            mem_ready <= 1'b1;
                        end
                        8'h0C: begin
                            if (|mem_wstrb) test_status <= mem_wdata;
                            mmio_rdata <= test_status;
                            mem_ready <= 1'b1;
                        end
                        8'h10: begin
                            if (!(|mem_wstrb)) begin
                                mmio_rdata <= 32'b0;
                                mem_ready <= 1'b1;
                            end else if (!tx_busy && !tx_start) begin
                                tx_byte <= mem_wdata[7:0];
                                tx_start <= 1'b1;
                                mem_ready <= 1'b1;
                            end
                        end
                        8'h14: begin
                            mmio_rdata <= {31'b0, !(tx_busy || tx_start)};
                            mem_ready <= 1'b1;
                        end
                        default: begin
                            mmio_rdata <= 32'hBAD0_0001;
                            mem_ready <= 1'b1;
                        end
                    endcase
                end else begin
                    return_rom <= 1'b0;
                    mmio_rdata <= 32'hBAD0_0002;
                    mem_ready <= 1'b1;
                end
            end
        end
    end
    wire _unused = uart_rx ^ mem_instr; // silence basic lint on reserved inputs
endmodule
