`timescale 1ns/1ps
// 1) timecode_df vs the SMPTE 59.94 drop-frame formula, every frame for 1 hour + 1 min.
// 2) renders one 720x480 frame of bars + overlay to sim/frame.ppm for a visual check,
//    and spot-checks box / text / background pixels.
module tb_overlay;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst_n = 0, tick = 0;
    wire [31:0] tc;
    timecode_df tcg (.clk(clk), .rst_n(rst_n), .tick(tick), .bcd(tc));

    reg  [9:0]  x, y;
    wire [2:0]  bar = x / 90;
    wire [23:0] bg = {((bar == 0 || bar == 1 || bar == 4 || bar == 5) ? 8'hFF : 8'h00),
                      ((bar == 0 || bar == 1 || bar == 2 || bar == 3) ? 8'hFF : 8'h00),
                      ((bar == 0 || bar == 2 || bar == 4 || bar == 6) ? 8'hFF : 8'h00)};
    wire [23:0] rgb;
    overlay ov (.x(x), .y(y), .bg(bg), .tc(tc), .rgb(rgb));

    // reference: frame count -> drop-frame timecode BCD
    function [31:0] df_ref(input integer n);
        integer d, m, a, ff, ss, mm, hh;
        reg [3:0] q [0:7];
        begin
            d = n / 35964; m = n % 35964;                    // 10-minute blocks
            a = n + 36 * d + ((m > 4) ? 4 * ((m - 4) / 3596) : 0);
            ff = a % 60; ss = (a / 60) % 60; mm = (a / 3600) % 60; hh = (a / 216000) % 24;
            q[0] = hh / 10; q[1] = hh % 10; q[2] = mm / 10; q[3] = mm % 10;
            q[4] = ss / 10; q[5] = ss % 10; q[6] = ff / 10; q[7] = ff % 10;
            df_ref = {q[0], q[1], q[2], q[3], q[4], q[5], q[6], q[7]};
        end
    endfunction

    integer n, f, xi, yi, errors = 0;
    initial begin
        // ---- timecode -------------------------------------------------------------
        repeat (2) @(posedge clk); rst_n = 1;
        for (n = 0; n <= 219_380; n = n + 1) begin          // > 1 hour of frames
            @(negedge clk);
            if (tc !== df_ref(n)) begin
                errors = errors + 1;
                if (errors < 5) $display("FAIL: frame %0d tc=%h want %h", n, tc, df_ref(n));
            end
            tick = 1; @(negedge clk); tick = 0;
        end
        // landmarks
        if (df_ref(3599)   !== 32'h00005959) $display("FAIL ref 3599");
        if (df_ref(3600)   !== 32'h00010004) $display("FAIL ref 3600");
        if (df_ref(35964)  !== 32'h00100000) $display("FAIL ref 35964");
        if (df_ref(215784) !== 32'h01000000) $display("FAIL ref 215784");
        if (errors) $fatal(1, "FAIL: %0d timecode errors", errors);
        $display("timecode: %0d frames match drop-frame reference (00:00:59;59 -> 00:01:00;04, 1 h = 215784 frames)", n);

        // ---- render a frame at 12:34:56;23 -----------------------------------------
        force tcg.bcd = 32'h12345623;
        f = $fopen("sim/frame.ppm", "w");
        $fwrite(f, "P3\n720 480\n255\n");
        for (yi = 0; yi < 480; yi = yi + 1)
            for (xi = 0; xi < 720; xi = xi + 1) begin
                x = xi; y = yi; #1;
                $fwrite(f, "%0d %0d %0d\n", rgb[23:16], rgb[15:8], rgb[7:0]);
            end
        $fclose(f);

        // spot checks
        x = 10;  y = 10;  #1; if (rgb !== 24'hFFFFFF) begin errors = errors + 1; $display("FAIL: bg white bar"); end
        x = 500; y = 100; #1; if (rgb !== 24'hFF0000) begin errors = errors + 1; $display("FAIL: bg red bar"); end
        x = 170; y = 306; #1; if (rgb !== 24'h000000) begin errors = errors + 1; $display("FAIL: box corner"); end
        x = 184 + 4*1 + 2; y = 320 + 2; #1;                // 'T' top bar, 2nd pixel
        if (rgb !== 24'hFFFFFF) begin errors = errors + 1; $display("FAIL: T not lit"); end
        if (errors) $fatal(1, "FAIL: %0d render errors", errors);
        $display("PASS: rendered sim/frame.ppm");
        $finish;
    end
endmodule
