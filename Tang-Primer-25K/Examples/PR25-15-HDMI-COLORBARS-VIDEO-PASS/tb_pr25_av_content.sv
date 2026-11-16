`timescale 1ns/1ps
module tb_pr25_av_content;
    logic clk_audio = 1'b0;
    logic reset = 1'b1;
    logic [10:0] cx = 11'd0;
    logic [9:0] cy = 10'd0;
    wire [23:0] rgb;
    wire [15:0] audio_sample_word [1:0];

    pr25_av_content dut (
        .clk_audio(clk_audio), .reset(reset), .cx(cx), .cy(cy),
        .rgb(rgb), .audio_sample_word(audio_sample_word)
    );
    always #10 clk_audio = ~clk_audio;

    integer saw_left_positive = 0;
    integer saw_left_negative = 0;
    integer saw_right_positive = 0;
    integer saw_right_negative = 0;
    integer i;

    task automatic check_rgb(input [10:0] x, input [9:0] y, input [23:0] expected);
        begin
            cx = x;
            cy = y;
            #2;
            if (rgb !== expected) begin
                $display("RGB FAIL x=%0d y=%0d got=%h expected=%h", x, y, rgb, expected);
                $fatal(1);
            end
        end
    endtask

    initial begin
        check_rgb(11'd0,    10'd0,   24'hFF0000);
        check_rgb(11'd319,  10'd600, 24'hFF0000);
        check_rgb(11'd320,  10'd600, 24'h00FF00);
        check_rgb(11'd640,  10'd600, 24'h0000FF);
        check_rgb(11'd960,  10'd600, 24'hFFFFFF);
        check_rgb(11'd1279, 10'd600, 24'hFFFFFF);
        check_rgb(11'd1279, 10'd705, 24'h000000);
        check_rgb(11'd1280, 10'd0,   24'h000000);
        check_rgb(11'd0,    10'd720, 24'h000000);

        repeat (3) @(negedge clk_audio);
        reset = 1'b0;
        for (i = 0; i < 256; i = i + 1) begin
            @(negedge clk_audio);
            case (audio_sample_word[0])
                16'h0800: saw_left_positive = saw_left_positive + 1;
                16'hF800: saw_left_negative = saw_left_negative + 1;
                default: $fatal(1, "LEFT amplitude unexpected: %h", audio_sample_word[0]);
            endcase
            case (audio_sample_word[1])
                16'h0800: saw_right_positive = saw_right_positive + 1;
                16'hF800: saw_right_negative = saw_right_negative + 1;
                default: $fatal(1, "RIGHT amplitude unexpected: %h", audio_sample_word[1]);
            endcase
        end
        if (saw_left_positive == 0 || saw_left_negative == 0 ||
            saw_right_positive == 0 || saw_right_negative == 0)
            $fatal(1, "One of the audio channels was constant");
        $display("PR25 AV CONTENT SIM PASS: four colour bars, stereo PCM +/-2048");
        $finish;
    end
endmodule
