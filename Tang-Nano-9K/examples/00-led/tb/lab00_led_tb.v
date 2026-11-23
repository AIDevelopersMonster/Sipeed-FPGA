// LAB-00: functional simulation with a 4-cycle LED interval.
`timescale 1ns/1ps
module lab00_led_tb;
    reg clk = 1'b0;
    reg reset_n = 1'b0;
    wire [5:0] led_n;
    reg [5:0] expected;
    integer step;

    always #5 clk = ~clk;

    lab00_led_top #(.CYCLES_PER_STEP(4)) dut (
        .clk(clk), .reset_n(reset_n), .led_n(led_n)
    );

    initial begin
        #2;
        if (led_n !== 6'b111110)
            $fatal(1, "reset LED state differs: got %b", led_n);
        reset_n = 1'b1;

        for (step = 1; step <= 12; step = step + 1) begin
            repeat (4) @(posedge clk);
            #1;
            expected = ~(6'b000001 << (step % 6));
            if (led_n !== expected)
                $fatal(1, "step=%0d expected %b, got %b", step, expected, led_n);
        end

        reset_n = 1'b0;
        #1;
        if (led_n !== 6'b111110)
            $fatal(1, "reset after running failed: got %b", led_n);

        $display("LAB00_RTL_SIM_PASS: 12 steps, wrap and reset");
        $finish;
    end
endmodule
