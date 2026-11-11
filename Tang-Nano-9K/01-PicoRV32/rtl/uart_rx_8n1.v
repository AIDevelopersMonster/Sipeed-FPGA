// UART 8N1 receiver for the Tang Nano 9K integrated USB serial bridge.
// 2-flop asynchronous input synchronizer and center-bit sampling.
// This is NOT a baud-oversampled, noise-filtering or autobaud receiver.
// SPDX-License-Identifier: MIT
module uart_rx_8n1 #(
    parameter integer CLOCK_HZ = 27000000,
    parameter integer BAUD = 115200,
    parameter integer DIV = (CLOCK_HZ + BAUD / 2) / BAUD,
    parameter integer HALF_DIV = DIV / 2
)(
    input wire clk,
    input wire reset_n,
    input wire rx,
    output reg [7:0] data,
    output reg valid,           // one clock pulse: a complete byte, valid stop bit
    output reg framing_error    // one clock pulse: invalid stop bit
);
    localparam [1:0] ST_IDLE = 2'd0, ST_START = 2'd1,
                     ST_DATA = 2'd2, ST_STOP = 2'd3;
    reg rx_meta;
    reg rx_sync;
    reg [1:0] state;
    reg [15:0] tick;
    reg [2:0] bit_index;
    reg [7:0] shift;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            rx_meta       <= 1'b1;
            rx_sync       <= 1'b1;
            state         <= ST_IDLE;
            tick          <= 16'd0;
            bit_index     <= 3'd0;
            shift         <= 8'd0;
            data          <= 8'd0;
            valid         <= 1'b0;
            framing_error <= 1'b0;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
            valid <= 1'b0;
            framing_error <= 1'b0;
            case (state)
                ST_IDLE: begin
                    if (!rx_sync) begin
                        // Go to the center of the apparent start bit.
                        tick <= HALF_DIV - 1;
                        state <= ST_START;
                    end
                end
                ST_START: begin
                    if (tick != 0) tick <= tick - 1'b1;
                    else if (!rx_sync) begin
                        // Start bit persists at its center. Next center = 1 bit later.
                        bit_index <= 3'd0;
                        tick <= DIV - 1;
                        state <= ST_DATA;
                    end else state <= ST_IDLE; // reject a false start
                end
                ST_DATA: begin
                    if (tick != 0) tick <= tick - 1'b1;
                    else begin
                        shift[bit_index] <= rx_sync;
                        tick <= DIV - 1;
                        if (bit_index == 3'd7) state <= ST_STOP;
                        else bit_index <= bit_index + 1'b1;
                    end
                end
                ST_STOP: begin
                    if (tick != 0) tick <= tick - 1'b1;
                    else begin
                        if (rx_sync) begin
                            data <= shift;
                            valid <= 1'b1;
                        end else begin
                            framing_error <= 1'b1;
                        end
                        state <= ST_IDLE;
                    end
                end
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule
