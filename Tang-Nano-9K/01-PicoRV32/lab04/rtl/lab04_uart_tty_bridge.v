// LAB-04.2. Passive UART taps -> SVO terminal byte stream (CPU clock domain).
// Both directions are decoded without affecting the processor UART pins.
// Two independent FIFOs prevent simultaneous RX/TX pulses from overwriting.
// Overflow is signaled only for diagnosis; it must not be reported as loss-free.
// SPDX-License-Identifier: MIT
module lab04_uart_tty_bridge #(
    parameter integer CLOCK_HZ = 27000000,
    parameter integer BAUD = 115200,
    parameter integer HOST_TAP_ENABLE = 1
)(
    input wire clk,
    input wire reset_n,
    input wire serial_from_pc,
    input wire serial_from_cpu,
    output wire char_valid,
    input wire char_ready,
    output wire [7:0] char_data,
    output reg host_overflow,
    output reg cpu_overflow
);
    wire [7:0] host_byte, cpu_byte;
    wire host_byte_valid, cpu_byte_valid;
    wire host_bad_frame, cpu_bad_frame;
    uart_rx_8n1 #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_host_monitor (
        .clk(clk), .reset_n(reset_n), .rx(serial_from_pc),
        .data(host_byte), .valid(host_byte_valid), .framing_error(host_bad_frame)
    );
    uart_rx_8n1 #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_cpu_monitor (
        .clk(clk), .reset_n(reset_n), .rx(serial_from_cpu),
        .data(cpu_byte), .valid(cpu_byte_valid), .framing_error(cpu_bad_frame)
    );
    reg [7:0] host_fifo [0:31];
    reg [7:0] cpu_fifo  [0:31];
    reg [5:0] host_wp, host_rp, cpu_wp, cpu_rp;
    reg prefer_host;
    wire host_empty = host_wp == host_rp;
    wire cpu_empty = cpu_wp == cpu_rp;
    wire host_full = (host_wp[5] != host_rp[5]) && (host_wp[4:0] == host_rp[4:0]);
    wire cpu_full = (cpu_wp[5] != cpu_rp[5]) && (cpu_wp[4:0] == cpu_rp[4:0]);
    wire take_host = !host_empty && (cpu_empty || prefer_host);
    wire take_cpu = !cpu_empty && (host_empty || !prefer_host);
    assign char_valid = !host_empty || !cpu_empty;
    assign char_data = take_host ? host_fifo[host_rp[4:0]] : cpu_fifo[cpu_rp[4:0]];
    wire pop_host = char_valid && char_ready && take_host;
    wire pop_cpu = char_valid && char_ready && take_cpu;

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            host_wp <= 0; host_rp <= 0;
            cpu_wp <= 0; cpu_rp <= 0;
            prefer_host <= 1;
            host_overflow <= 0; cpu_overflow <= 0;
        end else begin
            if (HOST_TAP_ENABLE && host_byte_valid) begin
                if (!host_full || pop_host) begin
                    host_fifo[host_wp[4:0]] <= host_byte;
                    host_wp <= host_wp + 1'b1;
                end else host_overflow <= 1'b1;
            end
            if (cpu_byte_valid) begin
                if (!cpu_full || pop_cpu) begin
                    cpu_fifo[cpu_wp[4:0]] <= cpu_byte;
                    cpu_wp <= cpu_wp + 1'b1;
                end else cpu_overflow <= 1'b1;
            end
            if (pop_host) host_rp <= host_rp + 1'b1;
            if (pop_cpu) cpu_rp <= cpu_rp + 1'b1;
            if (pop_host) prefer_host <= 0;
            if (pop_cpu) prefer_host <= 1;
        end
    end
    // Verilator/Icarus may flag unused frame-pulse wires. Frame errors are
    // not inserted into the terminal stream; the two monitor UARTs are passive.
    wire _unused = host_bad_frame ^ cpu_bad_frame;
endmodule
