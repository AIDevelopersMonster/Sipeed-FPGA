module tb_lab07_uart_result;
    reg clk=0, resetn=0;
    reg [3:0] test_state=0;
    wire tx;
    reg [111:0] expected;
    reg [7:0] received;
    integer k,b;
    always #5 clk=~clk;
    lab07_uart_result #(.CLOCK_HZ(1152000),.BAUD(115200))
      dut(.clk(clk),.resetn(resetn),.test_state(test_state),.uart_tx(tx));
    task automatic check_message;
        input [111:0] msg;
        begin
            for(k=0;k<14;k=k+1) begin
                @(negedge tx);
                repeat(5) @(posedge clk); #1;
                if(tx !== 1'b0) $fatal(1,"UART start %0d",k);
                for(b=0;b<8;b=b+1) begin
                    repeat(10) @(posedge clk); #1;
                    received[b]=tx;
                end
                repeat(10) @(posedge clk); #1;
                if(tx !== 1'b1) $fatal(1,"UART stop %0d",k);
                if(received !== msg[(13-k)*8 +: 8])
                    $fatal(1,"UART byte %0d got %h expected %h",
                        k,received,msg[(13-k)*8 +: 8]);
            end
        end
    endtask
    initial begin
        #1000000; $fatal(1,"LAB07_UART_TB_TIMEOUT");
    end
    initial begin
        repeat(5) @(posedge clk);
        #1 resetn=1;
        repeat(3) @(posedge clk);
        #1 test_state=4;
        expected="PSRAM07:PASS\r\n";
        check_message(expected);
        repeat(25) @(posedge clk);
        #1 resetn=0;
        repeat(5) @(posedge clk);
        #1 resetn=1;
        repeat(3) @(posedge clk);
        #1 test_state=8;
        expected="PSRAM07:FAIL\r\n";
        check_message(expected);
        $display("LAB07_UART_TB_PASS");
        $finish;
    end
endmodule
