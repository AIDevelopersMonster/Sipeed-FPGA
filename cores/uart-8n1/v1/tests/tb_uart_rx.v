`timescale 1ns/1ps
// Standalone 8N1 receiver test at real clock/baud divisor; no PicoRV32 needed.
module tb_uart_rx;
    localparam integer DIV = 234; // nearest 27 MHz / 115200
    reg clk = 0;
    reg reset_n = 0;
    reg rx = 1;
    wire [7:0] data;
    wire valid, framing_error;
    integer count = 0;
    integer errors = 0;
    reg [7:0] received [0:7];
    always #5 clk = ~clk;
    uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) dut (
        .clk(clk),.reset_n(reset_n),.rx(rx),
        .data(data),.valid(valid),.framing_error(framing_error)
    );
    always @(posedge clk) begin
        if (reset_n && valid) begin
            if (count >= 8) $fatal(1,"RX: excessive bytes");
            received[count] = data;
            count = count + 1;
        end
        if (reset_n && framing_error) errors = errors + 1;
    end
    task send_byte(input [7:0] value, input stop_high);
        integer bit_i;
        begin
            @(negedge clk); rx = 0;
            repeat(DIV) @(negedge clk);
            for(bit_i=0;bit_i<8;bit_i=bit_i+1) begin
                rx = value[bit_i];
                repeat(DIV) @(negedge clk);
            end
            rx = stop_high;
            repeat(DIV) @(negedge clk);
            rx = 1;
            repeat(DIV) @(negedge clk); // inter-frame idle
        end
    endtask
    initial begin
        repeat(10) @(negedge clk); reset_n = 1;
        // Short line glitch must not be confused with a start bit.
        @(negedge clk); rx=0;
        repeat(DIV/4) @(negedge clk);
        rx=1; repeat(DIV) @(negedge clk);
        if (count != 0) $fatal(1,"RX: false start accepted");
        send_byte(8'h31,1'b1); // '1'
        send_byte(8'h3f,1'b1); // '?'
        send_byte(8'h00,1'b1); // lowest possible byte
        send_byte(8'h7f,1'b0); // invalid stop bit: no data pulse, error pulse
        repeat(DIV*2) @(negedge clk);
        if (count !== 3) $fatal(1,"RX: got %0d bytes instead of 3",count);
        if (received[0] !== 8'h31 || received[1] !== 8'h3f || received[2] !== 8'h00)
            $fatal(1,"RX: incorrect 8N1 data");
        if (errors !== 1) $fatal(1,"RX: wrong framing error count %0d",errors);
        $display("LAB02_RX_RTL_PASS: normal bytes, 0x00, false-start, framing-error");
        $finish;
    end
    initial begin
        #200000; $fatal(1,"RX: timeout");
    end
endmodule
