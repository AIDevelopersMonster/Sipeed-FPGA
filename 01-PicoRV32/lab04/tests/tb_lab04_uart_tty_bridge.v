`timescale 1ns/1ps
// Tests passive two-direction UART -> character FIFO with a live handshake.
// This is NOT a Gowin PLL, TMDS or board test.
module tb_lab04_uart_tty_bridge;
    reg clk=0, reset_n=0;
    reg serial_from_pc=1, serial_from_cpu=1;
    wire [7:0] char_data;
    wire char_valid, host_overflow, cpu_overflow;
    reg char_ready=1;
    reg [7:0] observed [0:15];
    integer seen=0, i;
    always #18.5 clk = ~clk;
    lab04_uart_tty_bridge u_dut (
        .clk(clk), .reset_n(reset_n),
        .serial_from_pc(serial_from_pc), .serial_from_cpu(serial_from_cpu),
        .char_valid(char_valid), .char_ready(char_ready), .char_data(char_data),
        .host_overflow(host_overflow), .cpu_overflow(cpu_overflow)
    );
    always @(posedge clk) begin
        if (reset_n && char_valid && char_ready) begin
            if (seen > 15) $fatal(1,"too many chars");
            observed[seen] = char_data;
            seen = seen + 1;
        end
    end
    task send_host(input [7:0] val);
        integer k;
        begin
            serial_from_pc=0; #8680;
            for (k=0; k<8; k=k+1) begin serial_from_pc=val[k]; #8680; end
            serial_from_pc=1; #8680;
        end
    endtask
    task send_cpu(input [7:0] val);
        integer k;
        begin
            serial_from_cpu=0; #8680;
            for (k=0; k<8; k=k+1) begin serial_from_cpu=val[k]; #8680; end
            serial_from_cpu=1; #8680;
        end
    endtask
    initial begin
        #300; reset_n=1;
        #1000;
        // Coincident start bits exercise both independent input FIFOs.
        fork
            send_host(8'h34);
            send_cpu(8'h43);
        join
        #200000;
        if (seen != 2) $fatal(1,"expected 2 decoded chars, got %0d",seen);
        if (!((observed[0]==8'h34 && observed[1]==8'h43) ||
              (observed[0]==8'h43 && observed[1]==8'h34)))
            $fatal(1,"unexpected bytes %h %h",observed[0],observed[1]);
        if (host_overflow || cpu_overflow) $fatal(1,"unexpected FIFO overflow");
        $display("LAB04_UART_TTY_RTL_PASS: simultaneous host and CPU bytes captured");
        $finish;
    end
endmodule
