// LAB-05.1 mode-0 self-checking byte loopback test.
// Run: iverilog -g2012 -s tb_lab05_spi_byte -o lab05.vvp rtl/lab05_spi_byte.v tests/tb_lab05_spi_byte.v
//      vvp lab05.vvp
`timescale 1ns/1ps
module tb_lab05_spi_byte;
    reg clk=0;
    always #18.5 clk=~clk; // illustrative near-27-MHz test clock
    reg reset_n=0, start=0;
    reg [7:0] tx=0;
    wire sck,mosi,busy,done;
    wire [7:0] rx;
    // With CPHA=0, master captures bit presented at each rising edge.
    wire miso=mosi;
    integer edges=0, completions=0;
    reg sck_prev=0;
    lab05_spi_byte #(.HALF_PERIOD(3)) dut(
        .clk(clk),.reset_n(reset_n),.start(start),.tx_data(tx),
        .miso(miso),.sck(sck),.mosi(mosi),.busy(busy),.done(done),.rx_data(rx)
    );
    always @(posedge clk) begin
        if (reset_n && !sck_prev && sck) edges <= edges+1;
        sck_prev <= sck;
    end
    task transact(input [7:0] value);
        integer start_edges;
        integer timeout;
        begin
            start_edges=edges;
            @(negedge clk); tx=value;start=1;
            @(negedge clk);start=0;
            timeout=0;
            while (!done && timeout<1000) begin
                @(negedge clk);timeout=timeout+1;
            end
            if (!done) $fatal(1,"SPI timeout");
            if (rx !== value) $fatal(1,"SPI mismatch sent=%h received=%h",value,rx);
            if (edges-start_edges !== 8) $fatal(1,"SPI clock pulses=%0d",edges-start_edges);
            if (sck !== 0) $fatal(1,"SCK must idle low");
            completions=completions+1;
            @(negedge clk);
        end
    endtask
    initial begin
        repeat(3) @(negedge clk);reset_n=1;
        transact(8'h00);
        transact(8'hff);
        transact(8'ha5);
        transact(8'h3c);
        if(completions!=4) $fatal(1,"missing completions");
        $display("LAB05_SPI_BYTE_TB_PASS: 4 bytes, 32 clock pulses");
        $finish;
    end
    initial begin
        #250000;
        $fatal(1,"testbench watchdog");
    end
endmodule
