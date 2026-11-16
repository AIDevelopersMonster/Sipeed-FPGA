// Functional regression for the isolated VRAM block; not an FPGA timing test.
module tb_pikosol_vram_80x30;
    reg clk=0;
    always #5 clk=~clk;
    reg we=0;
    reg [11:0] waddr=0, raddr=0;
    reg [7:0] wdata=0;
    wire [7:0] rdata;
    pikosol_vram_80x30 dut(.clk(clk),.we(we),.waddr(waddr),
        .wdata(wdata),.raddr(raddr),.rdata(rdata));
    task tick;
        begin @(posedge clk); #1; end
    endtask
    initial begin
        // Stage writes on falling edges; don't inspect same-address
        // read-during-write semantics, which are device-specific.
        @(negedge clk); we=1; waddr=0; wdata=8'h41; raddr=2399;
        tick();
        @(negedge clk); we=1; waddr=2399; wdata=8'h5A; raddr=0;
        tick();
        if (rdata !== 8'h41) $fatal(1, "addr 0 read failed");
        @(negedge clk); we=0; raddr=2399;
        tick();
        if (rdata !== 8'h5A) $fatal(1, "addr 2399 read failed");
        @(negedge clk); raddr=2400;
        tick();
        if (rdata !== 8'h20) $fatal(1, "out-of-range guard failed");
        $display("SIM PASS: 80x30 VRAM boundary and synchronous reads");
        $finish;
    end
endmodule
