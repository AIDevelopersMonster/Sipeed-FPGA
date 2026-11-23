// Tang Nano 9K / LAB-00. Candidate RTL, not yet board tested.
// SPDX-License-Identifier: MIT
// A single active-low LED moves every 0.5 s at 27 MHz.
// CYCLES_PER_STEP is overridable in the testbench.
module lab00_led_top #(
    parameter integer CYCLES_PER_STEP = 13500000
) (
    input  wire       clk,
    input  wire       reset_n,
    output wire [5:0] led_n
);
    reg [23:0] tick_count;
    reg [2:0]  led_index;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            tick_count <= 24'd0;
            led_index  <= 3'd0;
        end else if (tick_count == CYCLES_PER_STEP - 1) begin
            tick_count <= 24'd0;
            if (led_index == 3'd5)
                led_index <= 3'd0;
            else
                led_index <= led_index + 3'd1;
        end else begin
            tick_count <= tick_count + 24'd1;
        end
    end

    // Onboard LEDs are active-low; only the selected LED is on.
    assign led_n = ~(6'b000001 << led_index);
endmodule
