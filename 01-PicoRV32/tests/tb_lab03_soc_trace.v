`timescale 1ns/1ps
// LAB-03.1 actual LAB-02 PicoRV32 SoC and UART + PASSIVE trace capture.
// This bench observes the existing SoC wires; no SoC or firmware edits.
// ROM values are independently checked against the generated boot.hex.
module tb_lab03_soc_trace;
    localparam integer BAUD_DIV = 234;
    localparam integer DEPTH = 128;
    reg clk=0,reset_n=0,uart_rx=1,clear=0;
    wire uart_tx;
    wire [5:0] led_n;
    wire [7:0] monitor_byte;
    wire monitor_valid,monitor_frame_error;
    reg [7:0] received [0:31];
    integer n=0;
    reg [31:0] rom [0:255];
    reg rd_req=0;
    reg [6:0] rd_index=0;
    wire rd_valid,capturing,done,truncated,overlap,timestamp_wrapped;
    wire [1:0] rd_kind;
    wire [31:0] rd_addr,rd_value;
    wire [15:0] rd_cycle;
    wire [7:0] command,count;
    integer i,fetches,stores,last_cycle;

    always #5 clk=~clk;
    initial $readmemh("firmware/boot.hex",rom);

    picorv32_soc dut(
        .clk(clk),.reset_n(reset_n),.uart_rx(uart_rx),
        .uart_tx(uart_tx),.led_n(led_n)
    );
    uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(115200)) monitor(
        .clk(clk),.reset_n(reset_n),.rx(uart_tx),
        .data(monitor_byte),.valid(monitor_valid),.framing_error(monitor_frame_error)
    );
    lab03_trace_capture #(.DEPTH(DEPTH)) recorder(
        .clk(clk),.reset_n(reset_n),.clear(clear),
        .rx_valid(dut.rx_valid),.rx_data(dut.rx_byte),
        .mem_valid(dut.mem_valid),.mem_ready(dut.mem_ready),
        .mem_instr(dut.mem_instr),.mem_addr(dut.mem_addr),
        .mem_rdata(dut.mem_rdata),.mem_wdata(dut.mem_wdata),.mem_wstrb(dut.mem_wstrb),
        .capturing(capturing),.done(done),.truncated(truncated),
        .overlap(overlap),.timestamp_wrapped(timestamp_wrapped),
        .command(command),.count(count),
        .rd_req(rd_req),.rd_index(rd_index),
        .rd_valid(rd_valid),.rd_kind(rd_kind),.rd_addr(rd_addr),
        .rd_value(rd_value),.rd_cycle(rd_cycle)
    );
    always @(posedge clk) begin
        if(reset_n && dut.cpu_trap) $fatal(1,"LAB03 SOC: CPU trap");
        if(reset_n && monitor_frame_error) $fatal(1,"LAB03 SOC: UART TX framing error");
        if(reset_n && monitor_valid) begin
            if(n>=32) $fatal(1,"LAB03 SOC: response log overflow");
            received[n]=monitor_byte;
            n=n+1;
        end
    end

    task host_send(input [7:0] ch);
        integer j;
        begin
            @(negedge clk);uart_rx=1'b0;
            repeat(BAUD_DIV) @(negedge clk);
            for(j=0;j<8;j=j+1) begin
                uart_rx=ch[j];
                repeat(BAUD_DIV) @(negedge clk);
            end
            uart_rx=1'b1;
            repeat(BAUD_DIV) @(negedge clk);
        end
    endtask
    task check_serial(input integer index,input [7:0] expected);
        begin
            if(received[index]!==expected)
                $fatal(1,"LAB03 SOC: serial byte[%0d] got %02x wanted %02x",index,received[index],expected);
        end
    endtask

    initial begin
        repeat(10) @(negedge clk);reset_n=1;
        wait(n==6);
        check_serial(0,"R");check_serial(1,"E");check_serial(2,"A");
        check_serial(3,"D");check_serial(4,"Y");check_serial(5,8'h0a);
        if (capturing || done || truncated || count!==0)
            $fatal(1,"LAB03 SOC: spurious snapshot on READY");

        host_send("4");
        wait(done || truncated);
        #1;
        if(!done || truncated || overlap || timestamp_wrapped)
            $fatal(1,"LAB03 SOC: failed/truncated capture: done=%d truncated=%d overlap=%d wrapped=%d count=%0d",done,truncated,overlap,timestamp_wrapped,count);
        if(command!=="4" || count<3)
            $fatal(1,"LAB03 SOC: incorrect command/count");
        fetches=0;stores=0;last_cycle=-1;
        for(i=0;i<count;i=i+1) begin
            @(negedge clk);rd_req=1;rd_index=i;
            @(posedge clk);#1;
            if(!rd_valid) $fatal(1,"LAB03 SOC: snapshot read failed at %0d",i);
            if(i>0 && rd_cycle<last_cycle) $fatal(1,"LAB03 SOC: timestamps decreased");
            last_cycle=rd_cycle;
            if(rd_kind==2'd1) begin
                fetches=fetches+1;
                if((rd_addr>=1024) || (rd_addr[1:0]!=0))
                    $fatal(1,"LAB03 SOC: fetch outside/alignment ROM 0x%08x",rd_addr);
                if(rd_value!==rom[rd_addr[9:2]])
                    $fatal(1,"LAB03 SOC: ROM mismatch at 0x%08x: trace=%08x hex=%08x",rd_addr,rd_value,rom[rd_addr[9:2]]);
            end else if(rd_kind==2'd2) begin
                stores=stores+1;
                if((i!=count-1) || (rd_addr!==32'h2000_0000) || (rd_value!==32'd8))
                    $fatal(1,"LAB03 SOC: captured wrong LED store: idx=%0d a=%08x v=%08x",i,rd_addr,rd_value);
            end else $fatal(1,"LAB03 SOC: unrecognized event kind %d",rd_kind);
        end
        @(negedge clk);rd_req=0;
        if(fetches<2 || stores!=1)
            $fatal(1,"LAB03 SOC: unexpected event composition fetches=%0d stores=%0d",fetches,stores);
        if(led_n!==6'b110111)
            $fatal(1,"LAB03 SOC: L4 physical output wrong: %b",led_n);
        wait(n==10);
        check_serial(6,"L");check_serial(7,"=");check_serial(8,"4");check_serial(9,8'h0a);
        $display("LAB03_1_SOC_TRACE_RTL_PASS: command=4, events=%0d fetches=%0d LED_STORE=0x8, verified boot.hex and L=4",count,fetches);
        $finish;
    end
    initial begin
        repeat(400000) @(posedge clk);
        $fatal(1,"LAB03 SOC: timeout, serial=%0d count=%0d done=%d truncated=%d",n,count,done,truncated);
    end
endmodule
