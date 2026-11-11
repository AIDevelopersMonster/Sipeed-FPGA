// 8N1 UART transmitter, no oversampling, stable CLOCK_HZ / BAUD divider.
// SPDX-License-Identifier: MIT
module uart_tx_8n1 #(
    parameter integer CLOCK_HZ = 27000000,
    parameter integer BAUD = 115200,
    parameter integer DIV = (CLOCK_HZ + BAUD/2) / BAUD
) (
    input wire clk,
    input wire reset_n,
    input wire start,
    input wire [7:0] data,
    output reg tx,
    output reg busy
);
    reg [9:0] frame;
    reg [15:0] div_count;
    reg [3:0] bits_done;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tx <= 1'b1;
            busy <= 1'b0;
            frame <= 10'h3ff;
            div_count <= 16'b0;
            bits_done <= 4'b0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (start) begin
                frame <= {1'b1, data, 1'b0};
                busy <= 1'b1;
                tx <= 1'b0;
                bits_done <= 4'd0;
                div_count <= DIV-1;
            end
        end else if (div_count != 0) begin
            div_count <= div_count - 1'b1;
        end else if (bits_done == 4'd9) begin
            busy <= 1'b0;
            tx <= 1'b1;
        end else begin
            // Start bit was emitted at start; shift through D0..D7 then stop.
            tx <= frame[1];
            frame <= {1'b1, frame[9:1]};
            bits_done <= bits_done + 1'b1;
            div_count <= DIV-1;
        end
    end
endmodule
