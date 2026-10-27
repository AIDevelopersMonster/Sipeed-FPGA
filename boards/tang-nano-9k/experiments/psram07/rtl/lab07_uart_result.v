// LAB-07 lightweight terminal UART, no dynamic 1024-bit print buffer.
// Only after existing PSRAM FSM state 4 (PASS) or 5..8 (FAIL).
module lab07_uart_result #(
    parameter integer CLOCK_HZ = 81000000,
    parameter integer BAUD = 115200
)(
    input wire clk,
    input wire resetn,
    input wire [3:0] test_state,
    output reg uart_tx
);
    localparam integer DIVISOR = CLOCK_HZ / BAUD;
    localparam integer TICK_WIDTH = $clog2(DIVISOR + 1);
    reg [TICK_WIDTH-1:0] ticks = 0;
    reg [3:0] old_state = 0;
    reg [3:0] char_index = 0;
    reg [3:0] bit_index = 0;
    reg [9:0] frame = 10'h3ff;
    reg pass_result = 0;
    reg sending = 0;
    function [7:0] get_char;
        input [3:0] index;
        input pass_flag;
        begin
            case (index)
                4'd0: get_char = "P";
                4'd1: get_char = "S";
                4'd2: get_char = "R";
                4'd3: get_char = "A";
                4'd4: get_char = "M";
                4'd5: get_char = "0";
                4'd6: get_char = "7";
                4'd7: get_char = ":";
                4'd8: get_char = pass_flag ? "P" : "F";
                4'd9: get_char = "A";
                4'd10: get_char = pass_flag ? "S" : "I";
                4'd11: get_char = pass_flag ? "S" : "L";
                4'd12: get_char = 8'h0d;
                4'd13: get_char = 8'h0a;
                default: get_char = 8'h00;
            endcase
        end
    endfunction
    initial uart_tx = 1'b1;
    always @(posedge clk) begin
        if (!resetn) begin
            ticks <= 0;
            old_state <= 0;
            char_index <= 0;
            bit_index <= 0;
            frame <= 10'h3ff;
            pass_result <= 0;
            sending <= 0;
            uart_tx <= 1'b1;
        end else begin
            old_state <= test_state;
            if (!sending) begin
                if (test_state != old_state &&
                    test_state >= 4'd4 && test_state <= 4'd8) begin
                    sending <= 1'b1;
                    pass_result <= (test_state == 4'd4);
                    char_index <= 0;
                    bit_index <= 0;
                    ticks <= 0;
                    frame <= {1'b1,get_char(4'd0,test_state == 4'd4),1'b0};
                    uart_tx <= 1'b0;
                end
            end else if (ticks == DIVISOR-1) begin
                ticks <= 0;
                if (bit_index == 4'd9) begin
                    if (char_index == 4'd13) begin
                        sending <= 0;
                        uart_tx <= 1'b1;
                    end else begin
                        char_index <= char_index + 4'd1;
                        bit_index <= 0;
                        frame <= {1'b1,get_char(char_index+4'd1,pass_result),1'b0};
                        uart_tx <= 1'b0;
                    end
                end else begin
                    bit_index <= bit_index + 4'd1;
                    uart_tx <= frame[1];
                    frame <= {1'b1,frame[9:1]};
                end
            end else ticks <= ticks + 1'b1;
        end
    end
endmodule
