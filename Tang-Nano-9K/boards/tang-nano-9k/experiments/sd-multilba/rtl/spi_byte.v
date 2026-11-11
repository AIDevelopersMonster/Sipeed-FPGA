// PiKoSoL LAB-05.1: SPI mode-0, one byte per transaction, one 27 MHz clock domain.
// HALF_PERIOD=64 -> 27 MHz/(2*64)=210.9 kHz, safe for initial SD negotiation.
// No derived/gated clock: SCK is a registered OUTPUT, all logic uses clk.
// SPDX-License-Identifier: MIT
module lab05_spi_byte #(
    parameter integer HALF_PERIOD = 64
) (
    input  wire       clk,
    input  wire       reset_n,
    input  wire       start,
    input  wire [7:0] tx_data,
    input  wire       miso,
    output reg        sck,
    output reg        mosi,
    output reg        busy,
    output reg        done,
    output reg  [7:0] rx_data
);
    reg [15:0] divider;
    reg        high_phase;
    reg [2:0]  bit_index;
    reg [7:0]  tx_hold;
    reg [7:0]  rx_hold;

    initial begin
        if (HALF_PERIOD < 2 || HALF_PERIOD > 65535)
            $error("HALF_PERIOD must be 2..65535");
    end

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            divider   <= 0;
            high_phase<= 0;
            bit_index <= 0;
            tx_hold   <= 8'hff;
            rx_hold   <= 0;
            sck       <= 0;
            mosi      <= 1;
            busy      <= 0;
            done      <= 0;
            rx_data   <= 0;
        end else begin
            done <= 1'b0;
            if (!busy) begin
                sck <= 1'b0;
                if (start) begin
                    busy       <= 1'b1;
                    high_phase <= 1'b0;
                    divider    <= HALF_PERIOD - 1;
                    bit_index  <= 3'd7;
                    tx_hold    <= tx_data;
                    rx_hold    <= 0;
                    mosi       <= tx_data[7];
                end else begin
                    mosi <= 1'b1;
                end
            end else if (divider != 0) begin
                divider <= divider - 1'b1;
            end else begin
                divider <= HALF_PERIOD - 1;
                if (!high_phase) begin
                    // Rising SCK: receiver samples a stable MOSI/MISO bit.
                    sck <= 1'b1;
                    rx_hold[bit_index] <= miso;
                    high_phase <= 1'b1;
                end else begin
                    // Falling SCK: present next bit or complete the byte.
                    sck <= 1'b0;
                    high_phase <= 1'b0;
                    if (bit_index == 0) begin
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        rx_data <= rx_hold;
                        mosi    <= 1'b1;
                    end else begin
                        bit_index <= bit_index - 1'b1;
                        mosi <= tx_hold[bit_index - 1'b1];
                    end
                end
            end
        end
    end
endmodule
