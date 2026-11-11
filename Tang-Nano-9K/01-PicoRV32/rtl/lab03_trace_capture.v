// LAB-03.1: passive, bounded capture of accepted PicoRV32 bus transactions.
// SPDX-License-Identifier: MIT
// The CPU/SoC is not modified. This module does not stall or acknowledge it.
// Captures accepted *fetches*, NOT committed/retired instructions.
// Captures the accepted LED MMIO write, not an optical LED measurement.
// Capture begins upon UART RX ASCII '0'..'6' and ends on first LED write.
// No claims about UART byte delivery to the CPU: trigger uses RX valid only.
module lab03_trace_capture #(
    parameter integer DEPTH = 128,
    parameter integer ADDR_W = (DEPTH > 1 ? $clog2(DEPTH) : 1),
    parameter integer COUNT_W = $clog2(DEPTH + 1)
)(
    input  wire clk,
    input  wire reset_n,
    input  wire clear,  // single-cycle synchronous clear; re-arms capture
    input  wire rx_valid,
    input  wire [7:0] rx_data,
    input  wire mem_valid,
    input  wire mem_ready,
    input  wire mem_instr,
    input  wire [31:0] mem_addr,
    input  wire [31:0] mem_rdata,
    input  wire [31:0] mem_wdata,
    input  wire [3:0] mem_wstrb,
    output reg capturing,
    output reg done,              // completed by an accepted LED write
    output reg truncated,         // full before LED write or abort on overlap
    output reg overlap,           // second supported RX command during capture
    output reg timestamp_wrapped, // 16-bit relative event timestamp rolled over
    output reg [7:0] command,     // ASCII trigger; independent of bus trace RAM
    output reg [COUNT_W-1:0] count,
    // Read after done/truncated. One clock latency, no write-side backpressure.
    input wire rd_req,
    input wire [ADDR_W-1:0] rd_index,
    output reg rd_valid,
    output reg [1:0] rd_kind,     // 01 accepted fetch, 10 accepted LED write
    output reg [31:0] rd_addr,
    output reg [31:0] rd_value,   // ROM instruction word, or LED write data
    output reg [15:0] rd_cycle    // cycles after trigger; may wrap (flagged)
);
    localparam [1:0] KIND_FETCH = 2'd1;
    localparam [1:0] KIND_LED_WRITE = 2'd2;
    localparam [31:0] LED_MMIO_ADDR = 32'h2000_0000;
    localparam [COUNT_W-1:0] LAST_SLOT = DEPTH - 1;

    // Packing gives one synchronous read port and one synchronous write port.
    // Memory contents are unspecified after reset; count/rd_valid delimit data.
    reg [81:0] events [0:DEPTH-1];
    reg [15:0] elapsed;
    wire trigger = rx_valid && (rx_data >= 8'h30) && (rx_data <= 8'h36);
    wire accepted = mem_valid && mem_ready;
    wire fetch_accept = accepted && mem_instr && (mem_wstrb == 4'b0000);
    wire led_write_accept = accepted && !mem_instr && (|mem_wstrb) &&
                            (mem_addr == LED_MMIO_ADDR);
    wire event_present = fetch_accept || led_write_accept;
    wire start = trigger && !capturing && !done && !truncated;
    wire active = capturing || start;
    wire [1:0] kind = led_write_accept ? KIND_LED_WRITE : KIND_FETCH;
    wire [31:0] value = led_write_accept ? mem_wdata : mem_rdata;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            capturing <= 1'b0;
            done <= 1'b0;
            truncated <= 1'b0;
            overlap <= 1'b0;
            timestamp_wrapped <= 1'b0;
            command <= 8'b0;
            count <= {COUNT_W{1'b0}};
            elapsed <= 16'b0;
            rd_valid <= 1'b0;
            rd_kind <= 2'b0;
            rd_addr <= 32'b0;
            rd_value <= 32'b0;
            rd_cycle <= 16'b0;
        end else if (clear) begin
            // Re-arming requires explicit clear, so an immutable snapshot
            // remains available after completion or truncation.
            capturing <= 1'b0;
            done <= 1'b0;
            truncated <= 1'b0;
            overlap <= 1'b0;
            timestamp_wrapped <= 1'b0;
            command <= 8'b0;
            count <= {COUNT_W{1'b0}};
            elapsed <= 16'b0;
            rd_valid <= 1'b0;
        end else begin
            rd_valid <= 1'b0;
            // Synchronous snapshot read; never read unwritten positions.
            if (rd_req && !capturing && (done || truncated) &&
                ({1'b0, rd_index} < count)) begin
                {rd_cycle, rd_kind, rd_addr, rd_value} <= events[rd_index];
                rd_valid <= 1'b1;
            end

            if (start) begin
                command <= rx_data;
                capturing <= 1'b1;
                elapsed <= 16'd0;
            end else if (capturing) begin
                elapsed <= elapsed + 1'b1;
                if (elapsed == 16'hffff) timestamp_wrapped <= 1'b1;
            end

            // A second command would mix two causal windows. Reject it
            // explicitly rather than silently misattribute bus events.
            if (capturing && trigger) begin
                capturing <= 1'b0;
                overlap <= 1'b1;
                truncated <= 1'b1;
            end else if (active && event_present) begin
                if (count < DEPTH) begin
                    // A start-triggered bus event is timestamped at cycle 0.
                    events[count[ADDR_W-1:0]] <= {
                        start ? 16'd0 : elapsed, kind, mem_addr, value
                    };
                    count <= count + 1'b1;
                    if (led_write_accept) begin
                        capturing <= 1'b0;
                        done <= 1'b1;
                    end else if (count == LAST_SLOT) begin
                        capturing <= 1'b0;
                        truncated <= 1'b1; // snapshot filled before LED store
                    end
                end else begin
                    capturing <= 1'b0;
                    truncated <= 1'b1;
                end
            end
        end
    end
endmodule
