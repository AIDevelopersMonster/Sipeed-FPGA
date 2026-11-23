`timescale 1ns/1ps
// Smoke test of the clocking with Gowin's primitive models: PLL locks,
// pixel clock = serial/5 (27 MHz), serial lanes toggle, TMDS clock lane carries 5 ones / 5 zeros.
module tb_top;
    reg clk = 0;
    always #18.518 clk = ~clk;          // 27 MHz
    wire [2:0] dp, dn;
    wire cp, cn, lock_n;
    top dut (.clk(clk), .rst_n(1'b1), .tmds_d_p(dp), .tmds_d_n(dn),
             .tmds_clk_p(cp), .tmds_clk_n(cn), .led_lock_n(lock_n));

    realtime t0, t1;
    integer edges = 0, ones = 0, zeros = 0, i;

    initial begin
        wait (lock_n == 0);
        $display("PLL locked at %0t ns", $realtime / 1000);
        repeat (20) @(posedge dut.pclk);
        @(posedge dut.pclk) t0 = $realtime;
        repeat (100) @(posedge dut.pclk);
        t1 = $realtime;
        if ((t1 - t0) / 100 < 36.5 || (t1 - t0) / 100 > 37.6)
            $fatal(1, "FAIL: pixel clock period %0.2f ns, want 37.04", (t1 - t0) / 100);

        // sample the TMDS clock lane at 10x per pixel for 50 pixels
        for (i = 0; i < 500; i = i + 1) begin
            #3.704;
            if (cp) ones = ones + 1; else zeros = zeros + 1;
            if (cp === cn) $fatal(1, "FAIL: clock pair not differential");
        end
        if (ones < 200 || zeros < 200) $fatal(1, "FAIL: TMDS clock lane duty %0d/%0d", ones, zeros);

        // data lane 0 must be toggling
        fork : watch
            begin repeat (50) @(dp[0]) edges = edges + 1; disable watch; end
            begin #2000; disable watch; end
        join
        if (edges < 50) $fatal(1, "FAIL: data lane 0 only %0d edges", edges);

        $display("PASS: pixel clock %0.2f ns, clock lane %0d/%0d, lane 0 toggling", (t1 - t0) / 100, ones, zeros);
        $finish;
    end

    initial begin #1_000_000; $fatal(1, "FAIL: timeout (no lock?)"); end
endmodule
