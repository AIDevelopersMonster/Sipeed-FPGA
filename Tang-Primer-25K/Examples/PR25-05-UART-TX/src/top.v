// PR25-05 UARTTX-PACKET: bounded, serialized UART diagnostic transmitter.
// Tang Primer 25K Dock: E2=50 MHz; C3=FPGA UART TX -> BL616 COM25.
// Single clock, no PLL, no CDC, no CPU, no UART RX or external reset.
// One packet = PACKET_BYTES bytes of a 19-byte ASCII reference message.
// MAX_PACKETS=16: total output 304 bytes per FPGA SRAM configuration.
// Each next packet starts only after the preceding packet's final STOP bit
// has been transmitted AND a whole GAP_CYCLES idle interval has elapsed.
module top #(
    parameter integer CLOCK_HZ = 50000000,
    parameter integer BAUD_RATE = 9600,
    parameter integer GAP_CYCLES = 25000000,
    parameter integer PACKET_BYTES = 19, // allowed 1..19; default full CRLF line
    parameter integer MAX_PACKETS = 16    // 0 means unlimited; test default is bounded
)(
    input wire clk_50m,
    output wire uart_tx
);
    localparam integer CLOCKS_PER_BIT =
        (CLOCK_HZ + BAUD_RATE/2) / BAUD_RATE;

    // Explicit packet state. No new packet can start in SEND or LOAD.
    localparam [1:0] ST_GAP  = 2'd0;
    localparam [1:0] ST_LOAD = 2'd1;
    localparam [1:0] ST_SEND = 2'd2;
    localparam [1:0] ST_DONE = 2'd3;

    reg [1:0]  state = ST_GAP;
    reg [31:0] gap_count = 0;
    reg [31:0] packets_completed = 0;
    reg [4:0]  byte_index = 0;
    reg [3:0]  bit_index = 0;
    reg [15:0] baud_count = 0;
    reg [9:0]  tx_shift = 10'h3FF; // UART idle HIGH at FPGA configuration

    assign uart_tx = tx_shift[0];

    function [7:0] packet_byte;
        input [4:0] index;
        begin
            case (index)
                5'd0:  packet_byte = 8'h50; // P
                5'd1:  packet_byte = 8'h52; // R
                5'd2:  packet_byte = 8'h32; // 2
                5'd3:  packet_byte = 8'h35; // 5
                5'd4:  packet_byte = 8'h20; // space
                5'd5:  packet_byte = 8'h55; // U
                5'd6:  packet_byte = 8'h41; // A
                5'd7:  packet_byte = 8'h52; // R
                5'd8:  packet_byte = 8'h54; // T
                5'd9:  packet_byte = 8'h20; // space
                5'd10: packet_byte = 8'h54; // T
                5'd11: packet_byte = 8'h58; // X
                5'd12: packet_byte = 8'h20; // space
                5'd13: packet_byte = 8'h54; // T
                5'd14: packet_byte = 8'h45; // E
                5'd15: packet_byte = 8'h53; // S
                5'd16: packet_byte = 8'h54; // T
                5'd17: packet_byte = 8'h0D; // CR
                5'd18: packet_byte = 8'h0A; // LF
                default: packet_byte = 8'h3F; // configuration error: ?
            endcase
        end
    endfunction

    // Synchronous sequencer. A packet is not buffered or queued anywhere.
    // The next byte is fetched only when the previous byte's stop bit ends.
    always @(posedge clk_50m) begin
        case (state)
            ST_GAP: begin
                tx_shift <= 10'h3FF;
                if (gap_count >= GAP_CYCLES-1) begin
                    gap_count <= 0;
                    byte_index <= 0;
                    state <= ST_LOAD;  // only packet creation point
                end else
                    gap_count <= gap_count + 1'b1;
            end

            ST_LOAD: begin
                // Start=0, eight data bits LSB first, Stop=1.
                tx_shift <= {1'b1, packet_byte(byte_index), 1'b0};
                bit_index <= 0;
                baud_count <= 0;
                state <= ST_SEND;
            end

            ST_SEND: begin
                if (baud_count >= CLOCKS_PER_BIT-1) begin
                    baud_count <= 0;
                    if (bit_index == 9) begin
                        // The complete STOP bit has elapsed.
                        tx_shift <= 10'h3FF;
                        if (byte_index == PACKET_BYTES-1) begin
                            packets_completed <= packets_completed + 1'b1;
                            if ((MAX_PACKETS != 0) &&
                                (packets_completed + 1 >= MAX_PACKETS))
                                state <= ST_DONE;
                            else
                                state <= ST_GAP; // wait before next packet
                        end else begin
                            byte_index <= byte_index + 1'b1;
                            state <= ST_LOAD; // next byte of same packet
                        end
                    end else begin
                        tx_shift <= {1'b1, tx_shift[9:1]};
                        bit_index <= bit_index + 1'b1;
                    end
                end else
                    baud_count <= baud_count + 1'b1;
            end

            default: begin // ST_DONE: FPGA TX remains permanently idle
                tx_shift <= 10'h3FF;
                state <= ST_DONE;
            end
        endcase
    end
endmodule
