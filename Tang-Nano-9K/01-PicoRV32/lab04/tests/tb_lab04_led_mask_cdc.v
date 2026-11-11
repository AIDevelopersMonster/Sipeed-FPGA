`timescale 1ns/1ps
// Coherent CDC mailbox RTL test. Two unrelated free-running clocks.
module tb_lab04_led_mask_cdc;
    reg clk_sys = 0;
    reg clk_pixel = 0;
    always #18.5 clk_sys = ~clk_sys;
    always #19.8 clk_pixel = ~clk_pixel;
    reg resetn_sys = 0;
    reg resetn_pixel = 0;
    reg [5:0] mask_sys = 0;
    wire [5:0] mask_pixel;
    lab04_led_mask_cdc dut(
        .clk_sys(clk_sys), .resetn_sys(resetn_sys), .mask_sys(mask_sys),
        .clk_pixel(clk_pixel), .resetn_pixel(resetn_pixel), .mask_pixel(mask_pixel)
    );
    task update_mask(input [5:0] new_mask);
        integer t;
        begin
            @(negedge clk_sys); mask_sys = new_mask;
            for (t=0; t<25; t=t+1) @(posedge clk_pixel);
            if (mask_pixel !== new_mask)
                $fatal(1,"CDC not settled: got %h, expected %h", mask_pixel, new_mask);
        end
    endtask
    reg atomic_mode = 0;
    always @(negedge clk_pixel) begin
        if (atomic_mode && resetn_pixel && mask_pixel !== 6'h00 && mask_pixel !== 6'h3f)
            $fatal(1,"CDC torn six-bit transfer: %h", mask_pixel);
    end
    initial begin
        repeat(5) @(negedge clk_sys);
        resetn_sys = 1;
        resetn_pixel = 1;
        update_mask(6'h01);
        update_mask(6'h20);
        update_mask(6'h00);
        atomic_mode = 1;
        update_mask(6'h3f);
        update_mask(6'h00);
        atomic_mode = 0;
        // A source can be updated before the previous ACK; newest wins.
        @(negedge clk_sys); mask_sys = 6'h0f;
        @(negedge clk_sys); mask_sys = 6'h2a;
        repeat(40) @(posedge clk_pixel);
        if (mask_pixel !== 6'h2a) $fatal(1,"rapid-update convergence failed");
        resetn_sys = 0;
        resetn_pixel = 0;
        repeat(3) @(negedge clk_sys);
        if (mask_pixel !== 0) $fatal(1,"reset mask is not zero");
        $display("LAB04_V016_CDC_RTL_PASS");
        $finish;
    end
    initial begin #300000; $fatal(1,"CDC bench timeout"); end
endmodule
