`timescale 1ns/1ps
// LAB-03.2: real UART TX/RX pin test of separate trace SoC, firmware T/C commands.
// Captures actual on-wire 115200 8N1 serial text and decodes it in Python.
// THIS IS AN RTL TESTBENCH, NOT A HARDWARE BOARD RESULT.
module tb_lab03_2_uart;
    localparam integer DIV = 234;
    reg clk=0, reset_n=0, rx=1;
    wire tx;
    wire [5:0] led_n;
    wire [7:0] monitor_data;
    wire monitor_valid, monitor_frame_error;
    reg [7:0] tx_log [0:8191];
    reg [7:0] prev_byte=0;
    integer tx_count=0, terminators=0;
    integer start_trace, end_trace, length_trace, first_length;
    reg [7:0] first_trace [0:4095];
    integer i, fd;

    always #5 clk=~clk;
    picorv32_soc_lab03 dut(.clk(clk),.reset_n(reset_n),.uart_rx(rx),
                          .uart_tx(tx),.led_n(led_n));
    uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) monitor(
        .clk(clk),.reset_n(reset_n),.rx(tx),
        .data(monitor_data),.valid(monitor_valid),.framing_error(monitor_frame_error));
    always @(posedge clk) begin
        if(reset_n && dut.cpu_trap) $fatal(1,"LAB03_2: CPU trap");
        if(reset_n && monitor_frame_error) $fatal(1,"LAB03_2: UART TX framing error");
        if(reset_n && monitor_valid) begin
            if(tx_count>=8192) $fatal(1,"LAB03_2: TX buffer overflow");
            tx_log[tx_count] = monitor_data;
            tx_count=tx_count+1;
            if(prev_byte==8'h5a && monitor_data==8'h0a)
                terminators=terminators+1; // exactly Z\n terminates trace
            prev_byte=monitor_data;
        end
    end
    task host_send(input [7:0] b);
        integer j;
        begin
            @(negedge clk);rx=0;
            repeat(DIV) @(negedge clk);
            for(j=0;j<8;j=j+1) begin
                rx=b[j];repeat(DIV) @(negedge clk);
            end
            rx=1;repeat(DIV) @(negedge clk);
        end
    endtask
    task expected(input integer index,input [7:0] b);
        begin
            if(tx_log[index]!==b)
                $fatal(1,"LAB03_2: TX[%0d] got=%02x expected=%02x",index,tx_log[index],b);
        end
    endtask
    task save_trace(input integer begin_index,input integer end_index,input integer which);
        begin
            case(which)
                1:fd=$fopen("build/lab03_2_trace_4.txt","w");
                2:fd=$fopen("build/lab03_2_trace_4_repeat.txt","w");
                3:fd=$fopen("build/lab03_2_trace_1.txt","w");
                default:$fatal(1,"LAB03_2: test script wrong trace number");
            endcase
            if(fd==0) $fatal(1,"LAB03_2: could not write trace log");
            for(i=begin_index;i<end_index;i=i+1)
                $fwrite(fd,"%c",tx_log[i]);
            $fclose(fd);
        end
    endtask
    initial begin
        repeat(10) @(negedge clk);reset_n=1;
        wait(tx_count==6);
        expected(0,"R");expected(1,"E");expected(2,"A");
        expected(3,"D");expected(4,"Y");expected(5,8'h0a);
        host_send("C");wait(tx_count==8);
        expected(6,"C");expected(7,8'h0a);
        host_send("4");wait(tx_count==12);
        expected(8,"L");expected(9,"=");expected(10,"4");expected(11,8'h0a);
        if(led_n!==6'b110111) $fatal(1,"LAB03_2: LED L4 not lit");
        if(!dut.trace_done || dut.trace_truncated || dut.trace_overlap)
            $fatal(1,"LAB03_2: trace capture 4 incomplete");

        start_trace=tx_count;
        host_send("T");wait(terminators==1);
        // NB: terminator includes UART TX end of byte, monitor_valid at stop center.
        end_trace=tx_count;first_length=end_trace-start_trace;
        if(first_length<100 || first_length>4096)
            $fatal(1,"LAB03_2: unreasonable dump length %0d",first_length);
        for(i=0;i<first_length;i=i+1) first_trace[i]=tx_log[start_trace+i];
        save_trace(start_trace,end_trace,1);

        start_trace=tx_count;
        host_send("T");wait(terminators==2);
        end_trace=tx_count;
        if((end_trace-start_trace)!=first_length)
            $fatal(1,"LAB03_2: readout changed dump size");
        for(i=0;i<first_length;i=i+1)
            if(tx_log[start_trace+i]!==first_trace[i])
                $fatal(1,"LAB03_2: immutable snapshot mismatch byte %0d",i);
        save_trace(start_trace,end_trace,2);
        if(led_n!==6'b110111) $fatal(1,"LAB03_2: T changed LED state");

        start_trace=tx_count;
        host_send("C");wait(tx_count==start_trace+2);
        expected(start_trace,"C");expected(start_trace+1,8'h0a);
        if(dut.trace_done || dut.trace_truncated || dut.trace_count!==0)
            $fatal(1,"LAB03_2: C did not clear snapshot");
        start_trace=tx_count;
        host_send("1");wait(tx_count==start_trace+4);
        expected(start_trace,"L");expected(start_trace+1,"=");
        expected(start_trace+2,"1");expected(start_trace+3,8'h0a);
        if(led_n!==6'b111110) $fatal(1,"LAB03_2: LED L1 not lit");
        if(!dut.trace_done || dut.trace_truncated)
            $fatal(1,"LAB03_2: second snapshot incomplete");

        start_trace=tx_count;
        host_send("T");wait(terminators==3);
        save_trace(start_trace,tx_count,3);
        $display("LAB03_2_UART_TRACE_RTL_PASS: READY, C, 4, T, repeated immutable T, C, 1, T; 115200 8N1; LED MMIO");
        $finish;
    end
    initial begin
        repeat(12000000) @(posedge clk);
        $fatal(1,"LAB03_2: timeout; tx_count=%0d terminators=%0d trace_done=%d",tx_count,terminators,dut.trace_done);
    end
endmodule
