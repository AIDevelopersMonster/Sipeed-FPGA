`timescale 1ns/1ps
// Deterministic standalone verification of LAB-03.1 capture contract.
module tb_lab03_trace_capture;
    reg clk=0, reset_n=0, clear=0;
    reg rx_valid=0;
    reg [7:0] rx_data=0;
    reg mem_valid=0,mem_ready=0,mem_instr=0;
    reg [31:0] mem_addr=0, mem_rdata=0, mem_wdata=0;
    reg [3:0] mem_wstrb=0;
    reg rd_req=0;
    reg [1:0] rd_index=0;
    wire capturing,done,truncated,overlap,timestamp_wrapped;
    wire [7:0] command;
    wire [2:0] count;
    wire rd_valid;
    wire [1:0] rd_kind;
    wire [31:0] rd_addr,rd_value;
    wire [15:0] rd_cycle;
    always #5 clk=~clk;
    lab03_trace_capture #(.DEPTH(4)) dut(
        .clk(clk),.reset_n(reset_n),.clear(clear),
        .rx_valid(rx_valid),.rx_data(rx_data),
        .mem_valid(mem_valid),.mem_ready(mem_ready),.mem_instr(mem_instr),
        .mem_addr(mem_addr),.mem_rdata(mem_rdata),.mem_wdata(mem_wdata),.mem_wstrb(mem_wstrb),
        .capturing(capturing),.done(done),.truncated(truncated),.overlap(overlap),
        .timestamp_wrapped(timestamp_wrapped),.command(command),.count(count),
        .rd_req(rd_req),.rd_index(rd_index),.rd_valid(rd_valid),
        .rd_kind(rd_kind),.rd_addr(rd_addr),.rd_value(rd_value),.rd_cycle(rd_cycle)
    );
    task cycle;
      begin @(posedge clk); #1; end
    endtask
    task drop_bus;
      begin
        @(negedge clk);
        mem_valid=0;mem_ready=0;mem_instr=0;mem_wstrb=0;
        rx_valid=0;
      end
    endtask
    task pulse_clear;
      begin
        @(negedge clk);clear=1;
        cycle();
        @(negedge clk);clear=0;
      end
    endtask
    task expect_event;
      input [1:0] idx;
      input [1:0] typ;
      input [31:0] addr;
      input [31:0] val;
      begin
        @(negedge clk);rd_index=idx;rd_req=1;
        cycle();
        if (!rd_valid || rd_kind!==typ || rd_addr!==addr || rd_value!==val)
          $fatal(1,"LAB03 standalone: event[%0d] kind=%d addr=%08x data=%08x",idx,rd_kind,rd_addr,rd_value);
        @(negedge clk);rd_req=0;
      end
    endtask
    initial begin
      repeat(4) cycle();
      @(negedge clk);reset_n=1;
      // Unsupported byte ('?') must not start capture.
      @(negedge clk);rx_valid=1;rx_data="?";
      cycle();
      if(capturing || count!=0) $fatal(1,"query improperly triggered capture");

      // Simultaneous UART RX and accepted fetch: trigger stored separately,
      // so NO event is lost and the fetch appears at timestamp zero.
      @(negedge clk);
      rx_data="4";rx_valid=1;mem_valid=1;mem_ready=1;mem_instr=1;
      mem_addr=32'h0000_0000;mem_rdata=32'h2000_02b7;mem_wstrb=0;
      cycle();
      if (!capturing || count!==1 || command!=="4")
        $fatal(1,"trigger + first fetch not captured");
      drop_bus();

      // Held *request* without mem_ready is NOT an accepted bus event.
      @(negedge clk);mem_valid=1;mem_ready=0;mem_instr=1;
      mem_addr=32'h0000_0004;mem_rdata=32'h0080_0313;
      repeat(3) cycle();
      if (count!==1) $fatal(1,"unacknowledged fetch recorded");
      @(negedge clk);mem_ready=1;
      cycle();
      if(count!==2) $fatal(1,"acknowledged second fetch not recorded");
      drop_bus();

      // Reads and unrelated writes may be accepted, but are not LED writes.
      @(negedge clk);mem_valid=1;mem_ready=1;mem_instr=0;
      mem_addr=32'h2000_0000;mem_wstrb=0;
      cycle();
      if(count!==2) $fatal(1,"MMIO read incorrectly captured");
      @(negedge clk);mem_addr=32'h2000_0010;mem_wstrb=4'b1111;
      cycle();
      if(count!==2) $fatal(1,"unrelated MMIO write incorrectly captured");

      // Accepted LED store ends snapshot and stays available until clear.
      @(negedge clk);mem_addr=32'h2000_0000;mem_wdata=32'd8;
      cycle();
      if(!done || capturing || truncated || count!==3)
        $fatal(1,"LED store did not finalize snapshot, count=%0d",count);
      drop_bus();
      expect_event(0,2'd1,32'h0000_0000,32'h2000_02b7);
      if(rd_cycle!==16'd0) $fatal(1,"trigger-concurrent event not timestamped zero");
      expect_event(1,2'd1,32'h0000_0004,32'h0080_0313);
      expect_event(2,2'd2,32'h2000_0000,32'd8);
      @(negedge clk);rd_req=1;rd_index=2'd3;
      cycle();
      if(rd_valid) $fatal(1,"out-of-range read unexpectedly valid");
      @(negedge clk);rd_req=0;
      // Immutable after DONE, even if another command and bus arrive.
      @(negedge clk);rx_valid=1;rx_data="6";mem_valid=1;mem_ready=1;
      mem_instr=1;mem_addr=32'h8;mem_rdata=32'habcd;
      cycle();
      if(count!==3 || !done) $fatal(1,"snapshot overwritten after done");
      drop_bus();

      // Early full => truncated, never misreported as a complete LED write.
      pulse_clear();
      @(negedge clk);rx_valid=1;rx_data="1";
      cycle();drop_bus();
      if (!capturing || command!=="1") $fatal(1,"rearm after clear failed");
      begin : fill_snap
        integer i;
        for(i=0;i<4;i=i+1) begin
          @(negedge clk);mem_valid=1;mem_ready=1;mem_instr=1;
          mem_addr=i*4;mem_rdata=32'h1000+i;
          cycle();
        end
      end
      drop_bus();
      if(!truncated || done || capturing || count!==4 || overlap)
        $fatal(1,"full snapshot not flagged as truncated");
      expect_event(3,2'd1,32'h0000_000c,32'h0000_1003);

      // Exact-fit LED store in final slot is a legitimate success.
      pulse_clear();
      @(negedge clk);rx_valid=1;rx_data="6";
      cycle();drop_bus();
      begin : last_store
        integer k;
        for(k=0;k<3;k=k+1) begin
          @(negedge clk);mem_valid=1;mem_ready=1;mem_instr=1;
          mem_addr=k*4;mem_rdata=32'h2000+k;
          cycle();
        end
      end
      @(negedge clk);mem_instr=0;mem_addr=32'h2000_0000;
      mem_wdata=32'd32;mem_wstrb=4'b1111;
      cycle();drop_bus();
      if(!done || truncated || count!==4)
        $fatal(1,"exact-fit store should be DONE not TRUNCATED");
      expect_event(3,2'd2,32'h2000_0000,32'd32);

      // Overlapping command aborts with explicit ambiguity flag.
      pulse_clear();
      @(negedge clk);rx_valid=1;rx_data="2";
      cycle();drop_bus();
      @(negedge clk);rx_valid=1;rx_data="3";
      cycle();drop_bus();
      if(!overlap || !truncated || done || capturing)
        $fatal(1,"overlapping command not flagged");
      $display("LAB03_1_TRACE_UNIT_RTL_PASS: triggers, accepted transfers, readback, full, exact-fit, overlap");
      $finish;
    end
    initial begin
      repeat(1000) @(posedge clk);
      $fatal(1,"LAB03 standalone timeout");
    end
endmodule
