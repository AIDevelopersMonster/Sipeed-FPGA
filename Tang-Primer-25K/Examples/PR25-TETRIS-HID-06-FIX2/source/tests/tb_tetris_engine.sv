`timescale 1ns/1ps
module tb_tetris_engine;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst = 1, en = 1, report_pulse = 0;
    reg [7:0] k0 = 0, k1 = 0, k2 = 0, k3 = 0, k4 = 0, k5 = 0, mod = 0;
    reg [9:0] x = 0, y = 0;
    wire [23:0] rgb;
    wire [15:0] lines, score;
    wire over, paused;
    tetris_engine #(.CLK_MHZ(1)) dut (
        .clk(clk),.rst(rst),.enable(en),.report_pulse(report_pulse),
        .key0(k0),.key1(k1),.key2(k2),.key3(k3),.key4(k4),.key5(k5),
        .modifiers(mod),.x(x),.y(y),.rgb(rgb),
        .lines_out(lines),.score_out(score),.game_over_out(over),.paused_out(paused)
    );
    task send(input [7:0] code);
        begin
            @(negedge clk); k0=code; report_pulse=1;
            @(negedge clk); report_pulse=0;
        end
    endtask
    integer i, count_occupied;
    initial begin
        repeat(4) @(negedge clk);
        rst=0;
        repeat(3) @(negedge clk);
        if (dut.phase !== 3'd1) $fatal(1,"TETRIS: not active after spawn");
        send(8'h21); // Numeric 4 = hard drop (verified HID keyboard code)
        repeat(75) @(negedge clk);
        count_occupied=0;
        for(i=0;i<20;i=i+1) begin
            if (dut.board[i] != 0) count_occupied=count_occupied+1;
        end
        if (count_occupied == 0) $fatal(1,"TETRIS: hard drop did not lock a piece");
        if (score !== 16'h0000) $fatal(1,"TETRIS: unexpected score");
        send(8'h00); // release key 4
        send(8'h15); // R restart
        repeat(5) @(negedge clk);
        for(i=0;i<20;i=i+1)
            if(dut.board[i] !== 10'd0) $fatal(1,"TETRIS: R did not clear board");
        if (over !== 1'b0) $fatal(1,"TETRIS: game over after reset");
        $display("PASS tetris_engine: spawn, hard drop, lock, R restart");
        $finish;
    end
    initial begin
        #2000000; $fatal(1,"TETRIS testbench timeout");
    end
endmodule
