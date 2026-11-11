`timescale 1ns/1ps
// Full PicoRV32 + ROM + MMIO + UART TX/RX console test.
// The physical 8N1 TX pin is decoded by a SECOND RX module as a line monitor.
// This is RTL simulation only. Does not establish physical BOARD_PASS.
module tb_uart_console;
    localparam integer DIV = 234;
    reg clk = 0, reset_n = 0, rx = 1;
    wire tx;
    wire [5:0] led_n;
    wire [7:0] observed_byte;
    wire observed_valid, observed_error;
    integer n = 0;
    reg [7:0] log_data [0:63];

    always #5 clk = ~clk;
    picorv32_soc dut(.clk(clk), .reset_n(reset_n), .uart_rx(rx),
                     .uart_tx(tx), .led_n(led_n));
    uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) tx_monitor (
        .clk(clk),.reset_n(reset_n),.rx(tx),
        .data(observed_byte),.valid(observed_valid),.framing_error(observed_error)
    );
    always @(posedge clk) begin
        if (reset_n && dut.cpu_trap) $fatal(1,"LAB02 SOC: CPU trapped");
        if (reset_n && observed_error) $fatal(1,"LAB02 SOC: TX stop-bit error");
        if (reset_n && observed_valid) begin
            if (n >= 64) $fatal(1,"LAB02 SOC: TX log overflow");
            log_data[n] = observed_byte;
            n = n+1;
        end
    end
    task host_send(input [7:0] value);
        integer i;
        begin
            @(negedge clk); rx = 1'b0;
            repeat(DIV) @(negedge clk);
            for (i=0;i<8;i=i+1) begin
                rx = value[i];
                repeat(DIV) @(negedge clk);
            end
            rx = 1'b1;
            repeat(DIV) @(negedge clk);
        end
    endtask
    task expect_byte(input integer idx, input [7:0] val);
        begin
            if (log_data[idx] !== val)
                $fatal(1,"LAB02 SOC: TX byte[%0d]=0x%02x, expected 0x%02x",idx,log_data[idx],val);
        end
    endtask
    initial begin
        repeat(10) @(negedge clk); reset_n = 1;
        wait (n == 6);
        expect_byte(0,"R");expect_byte(1,"E");expect_byte(2,"A");
        expect_byte(3,"D");expect_byte(4,"Y");expect_byte(5,8'h0a);
        if (led_n !== 6'b111111) $fatal(1,"LAB02 SOC: LEDs not off at boot");

        host_send("1");
        wait (n == 10);
        expect_byte(6,"L");expect_byte(7,"=");expect_byte(8,"1");expect_byte(9,8'h0a);
        if (led_n !== 6'b111110) $fatal(1,"LAB02 SOC: L1 must be on");

        host_send("4");
        wait (n == 14);
        expect_byte(10,"L");expect_byte(11,"=");expect_byte(12,"4");expect_byte(13,8'h0a);
        if (led_n !== 6'b110111) $fatal(1,"LAB02 SOC: L4 must be on, others off");

        host_send("?");
        wait (n == 18);
        expect_byte(14,"L");expect_byte(15,"=");expect_byte(16,"4");expect_byte(17,8'h0a);
        if (led_n !== 6'b110111) $fatal(1,"LAB02 SOC: query changed LEDs");

        host_send("0");
        wait (n == 22);
        expect_byte(18,"L");expect_byte(19,"=");expect_byte(20,"0");expect_byte(21,8'h0a);
        if (led_n !== 6'b111111) $fatal(1,"LAB02 SOC: all LEDs must be off");

        host_send("X");
        wait (n == 24);
        expect_byte(22,"E");expect_byte(23,8'h0a);
        if (led_n !== 6'b111111) $fatal(1,"LAB02 SOC: invalid command changed LEDs");
        $display("LAB02_SOC_RTL_PASS: READY, 1, 4, ?, 0, X and physical LED outputs");
        $finish;
    end
    initial begin
        // About 1.5 ms for the whole test at its accelerated simulation timebase.
        repeat(2000000) @(posedge clk);
        $fatal(1,"LAB02 SOC: timeout, TX bytes=%0d, PC=0x%08x",n,dut.cpu.mem_addr);
    end
endmodule
