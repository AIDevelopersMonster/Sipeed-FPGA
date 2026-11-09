`timescale 1ns/1ps
module tb_video_wb_overlay;
  reg cpu_clk=0, pix_clk=0, cpu_rst=1, pix_rst=1;
  always #10 cpu_clk=~cpu_clk;
  always #7 pix_clk=~pix_clk;
  reg cyc=0, stb=0, we=0;
  reg [7:0] adr=0;
  reg [31:0] wdata=0;
  reg [3:0] sel=4'hf;
  wire [31:0] rdata;
  wire ack, err;
  reg frame_start=0, de=1;
  reg [11:0] x=0,y=0;
  wire [7:0] r,g,b;
  integer cycles;
  video_wb_overlay dut (
    .cpu_clk(cpu_clk),.cpu_rst(cpu_rst),.wb_cyc_i(cyc),.wb_stb_i(stb),
    .wb_we_i(we),.wb_adr_i(adr),.wb_dat_i(wdata),.wb_sel_i(sel),
    .wb_dat_o(rdata),.wb_ack_o(ack),.wb_err_o(err),
    .pix_clk(pix_clk),.pix_rst(pix_rst),.frame_start(frame_start),
    .pix_de(de),.pix_x(x),.pix_y(y),.pix_r(r),.pix_g(g),.pix_b(b)
  );
  task transact;
    input integer wr;
    input [7:0] a;
    input [31:0] d;
    input integer expect_error;
    begin
      @(negedge cpu_clk);
      cyc=1;stb=1;we=wr;adr=a;wdata=d;
      cycles=0;
      begin : wait_rsp
        forever begin
          @(posedge cpu_clk);
          #1;
          cycles=cycles+1;
          if(ack || err) begin
            if (expect_error && !err) $fatal(1,"expected bus error @%h", a);
            if (!expect_error && (!ack || err)) $fatal(1,"expected ack @%h", a);
            disable wait_rsp;
          end
          if(cycles>12) $fatal(1,"Wishbone timeout @%h",a);
        end
      end
      @(negedge cpu_clk);
      cyc=0;stb=0;we=0;adr=0;
      repeat(2) @(posedge cpu_clk);
    end
  endtask
  task expect_rgb;
    input [23:0] want;
    begin
      #2;
      if ({r,g,b}!==want)
        $fatal(1,"RGB mismatch x=%0d y=%0d want %h got %h",x,y,want,{r,g,b});
    end
  endtask
  task frame_tick;
    begin
      @(negedge pix_clk);frame_start=1;
      @(negedge pix_clk);frame_start=0;
    end
  endtask
  initial begin
    repeat(5) @(negedge cpu_clk);
    cpu_rst=0;pix_rst=0;
    x=5;y=6;expect_rgb(24'h102040);
    transact(0,8'h00,0,0);
    if (rdata!==32'h56323031) $fatal(1,"ID readback mismatch");
    transact(1,8'h04,32'h00224466,0);
    transact(1,8'h08,{16'd6,16'd5},0);
    transact(1,8'h0c,{16'd3,16'd4},0);
    transact(1,8'h10,32'h00aa55cc,0);
    // staged settings must not yet affect pixels
    expect_rgb(24'h102040);
    transact(1,8'h18,32'h1,0);
    transact(1,8'h04,32'h00999999,1); // cannot modify stage during commit
    expect_rgb(24'h102040);
    // Cross the toggle into pixel domain before frame start
    repeat(5) @(posedge pix_clk);
    expect_rgb(24'h102040);
    frame_tick();
    expect_rgb(24'haa55cc);
    x=9;expect_rgb(24'h224466); // outside rectangle
    de=0;expect_rgb(24'h000000);
    de=1;x=5;expect_rgb(24'haa55cc);
    repeat(6) @(posedge cpu_clk);
    transact(0,8'h14,0,0);
    if(rdata[0]!==0) $fatal(1,"BUSY stuck after frame acknowledgement");
    // no-op frame without new commit must not change values
    frame_tick();expect_rgb(24'haa55cc);
    $display("SIM PASS EX20-05 overlay Wishbone/CDC/frame boundary");
    $finish;
  end
  initial begin
    #100000;
    $fatal(1,"global watchdog");
  end
endmodule
