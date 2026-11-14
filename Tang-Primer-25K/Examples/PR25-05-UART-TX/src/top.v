// PR25-05: Tang Primer 25K Dock, standalone periodic UART transmitter.
// Independent of RISC-V, USB Host, PLL, BRAM, firmware, and UART RX.
// Physical port: E2 = onboard 50 MHz oscillator; C3 = FPGA TX -> BL616 UART RX.
// Output: "PR25 UART TX TEST\r\n" every ~0.5 s, 8N1.
// Source defaults to 9600 for robust serial debugging; 115200 passed earlier.
module top #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD_RATE = 9600,
    parameter integer GAP_CYCLES = 25000000
)(
    input  wire clk_50m,
    output wire uart_tx
);

    localparam integer CLOCKS_PER_BIT = (CLOCK_HZ + BAUD_RATE/2) / BAUD_RATE;
    localparam integer MESSAGE_LEN = 19;

    // Explicit FPGA power-up initialization. No external reset needed.
    reg [9:0]  tx_bits = 10'h3FF;
    reg [15:0] baud_timer = 0;
    reg [3:0]  bit_index = 0;
    reg [4:0]  char_index = 0;
    reg [25:0] gap_timer = 0;
    reg        busy = 1'b0;

    assign uart_tx = tx_bits[0];

    function [7:0] msg_char;
        input [4:0] index;
        begin
            case (index)
            5'd0: msg_char = 8'h50;
            5'd1: msg_char = 8'h52;
            5'd2: msg_char = 8'h32;
            5'd3: msg_char = 8'h35;
            5'd4: msg_char = 8'h20;
            5'd5: msg_char = 8'h55;
            5'd6: msg_char = 8'h41;
            5'd7: msg_char = 8'h52;
            5'd8: msg_char = 8'h54;
            5'd9: msg_char = 8'h20;
            5'd10: msg_char = 8'h54;
            5'd11: msg_char = 8'h58;
            5'd12: msg_char = 8'h20;
            5'd13: msg_char = 8'h54;
            5'd14: msg_char = 8'h45;
            5'd15: msg_char = 8'h53;
            5'd16: msg_char = 8'h54;
            5'd17: msg_char = 8'h0D;
            5'd18: msg_char = 8'h0A;
                default: msg_char = 8'h3F;
            endcase
        end
    endfunction

    // Frame: 1 stop bit, 8 data bits LSB first, 1 start bit.
    // Shift only at one full bit interval.
    always @(posedge clk_50m) begin
        if (!busy) begin
            tx_bits <= 10'h3FF; // idle HIGH
            if ((char_index != 0) || (gap_timer == GAP_CYCLES - 1)) begin
                busy       <= 1'b1;
                tx_bits    <= {1'b1, msg_char(char_index), 1'b0};
                bit_index  <= 0;
                baud_timer <= 0;
                if (char_index == 0)
                    gap_timer <= 0;
            end else begin
                gap_timer <= gap_timer + 1'b1;
            end
        end else if (baud_timer == CLOCKS_PER_BIT - 1) begin
            baud_timer <= 0;
            tx_bits <= {1'b1, tx_bits[9:1]};
            if (bit_index == 9) begin
                busy      <= 1'b0;
                bit_index <= 0;
                if (char_index == MESSAGE_LEN - 1)
                    char_index <= 0;
                else
                    char_index <= char_index + 1'b1;
            end else begin
                bit_index <= bit_index + 1'b1;
            end
        end else begin
            baud_timer <= baud_timer + 1'b1;
        end
    end
endmodule
