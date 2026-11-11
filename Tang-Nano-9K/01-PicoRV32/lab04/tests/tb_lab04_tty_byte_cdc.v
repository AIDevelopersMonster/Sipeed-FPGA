`timescale 1ns/1ps
module tb_lab04_tty_byte_cdc;
  reg clk_sys=0, clk_pixel=0;
  always #18.5 clk_sys=~clk_sys;
  always #20 clk_pixel=~clk_pixel;
  reg resetn_sys=0, resetn_pixel=0;
  reg char_valid=0, pixel_accept=0;
  reg [7:0] char_data=0;
  wire char_ready, event_valid;
  wire [7:0] event_byte;
  integer num_seen=0;
  reg [7:0] expected [0:3];
  lab04_tty_byte_cdc dut (
   .clk_sys(clk_sys),.resetn_sys(resetn_sys),
   .char_valid(char_valid),.char_ready(char_ready),.char_data(char_data),
   .clk_pixel(clk_pixel),.resetn_pixel(resetn_pixel),
   .pixel_accept(pixel_accept),.event_valid(event_valid),.event_byte(event_byte)
  );
  always @(posedge clk_pixel) begin
    if(resetn_pixel && event_valid) begin
      if(num_seen>=4 || event_byte!==expected[num_seen]) begin
        $display("BYTE CDC FAIL: event %0d byte=%h",num_seen,event_byte);
        $fatal(1);
      end
      num_seen=num_seen+1;
    end
  end
  task send;
    input [7:0] value;
    begin
      @(negedge clk_sys);
      while (!char_ready) @(negedge clk_sys);
      char_data=value;char_valid=1;
      @(negedge clk_sys);char_valid=0;
    end
  endtask
  initial begin
    expected[0]=8'h41;expected[1]=8'h0a;
    expected[2]=8'h42;expected[3]=8'h70;
    #100;resetn_sys=1;resetn_pixel=1;
    send(8'h41);
    repeat(15) @(posedge clk_pixel);
    if(num_seen!=0) $fatal(1,"CDC must hold event while pixel_accept=0");
    pixel_accept=1;
    send(8'h0a);send(8'h42);send(8'h70);
    repeat(35) @(posedge clk_pixel);
    if(num_seen!=4) $fatal(1,"CDC dropped bytes, seen=%0d",num_seen);
    $display("LAB04_V018B_TTY_BYTE_CDC_RTL_PASS: 4 ordered bytes, ready/valid stalled");
    $finish;
  end
  initial begin #150000;$fatal(1,"CDC simulation timeout");end
endmodule
