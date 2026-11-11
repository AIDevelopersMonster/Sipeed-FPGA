`timescale 1ns/1ps
// Lossless asynchronous video-command CDC: 40 transactions, order, no dup/drop.
module tb_lab04_video_cmd_cdc;
    reg clk_sys = 0, clk_pixel = 0;
    always #18.5 clk_sys = ~clk_sys;
    always #19.8 clk_pixel = ~clk_pixel;
    reg resetn_sys = 0, resetn_pixel = 0;
    reg wr_valid = 0;
    wire wr_ready;
    reg [3:0] wr_index = 0;
    reg [23:0] wr_value = 0;
    wire event_valid;
    wire [3:0] event_index;
    wire [23:0] event_value;
    reg [27:0] expected [0:39];
    integer n, seen = 0, i;
    lab04_video_cmd_cdc dut(
        .clk_sys(clk_sys), .resetn_sys(resetn_sys),
        .wr_valid(wr_valid), .wr_ready(wr_ready),
        .wr_index(wr_index), .wr_value(wr_value),
        .clk_pixel(clk_pixel), .resetn_pixel(resetn_pixel),
        .event_valid(event_valid), .event_index(event_index),
        .event_value(event_value)
    );
    always @(posedge clk_pixel) begin
        if (resetn_pixel && event_valid) begin
            if (seen >= 40) $fatal(1,"duplicate event");
            if ({event_index,event_value} !== expected[seen])
                $fatal(1,"CDC mismatch event %0d got %h exp %h",
                       seen,{event_index,event_value},expected[seen]);
            seen = seen + 1;
        end
    end
    task send(input [3:0] ix, input [23:0] value);
        integer timeout;
        begin
            @(negedge clk_sys);
            wr_valid = 1; wr_index = ix; wr_value = value;
            timeout = 0;
            while (!wr_ready) begin
                @(negedge clk_sys); timeout = timeout + 1;
                if (timeout > 100) $fatal(1,"mailbox never ready");
            end
            @(posedge clk_sys); // accepted
            @(negedge clk_sys); wr_valid = 0;
        end
    endtask
    initial begin
        for (i=0;i<40;i=i+1)
            expected[i] = {i[3:0],24'h5a0000 ^ (i * 24'h12345)};
        repeat(4) @(negedge clk_sys);
        resetn_sys = 1; resetn_pixel = 1;
        for(n=0;n<40;n=n+1)
            send(expected[n][27:24],expected[n][23:0]);
        repeat(30) @(posedge clk_pixel);
        if(seen != 40) $fatal(1,"lost CDC events, got %0d",seen);
        resetn_sys = 0; resetn_pixel = 0;
        repeat(3) @(posedge clk_pixel);
        if (event_valid !== 0) $fatal(1,"reset should clear event pulse");
        $display("LAB04_V017_VIDEO_CDC_RTL_PASS events=%0d",seen);
        $finish;
    end
    initial begin #500000; $fatal(1,"CDC test timeout"); end
endmodule
