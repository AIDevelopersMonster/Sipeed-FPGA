`timescale 1ns/1ps
// W01 bit-level UART 8N1 + digest check + FPGA CPU cycle count: real PicoRV32.
module tb_w01_pico;
  reg clk=0, rstn=0, rx=1;
  always #18.518 clk=~clk;
  wire tx;
  wire [5:0] leds;
  w01_pico_soc dut(.clk_i(clk),.rstn_i(rstn),.uart0_rxd_i(rx),
                    .uart0_txd_o(tx),.led_n_o(leds));

  localparam integer N=23;
  localparam [8*13-1:0] PREFIX="W01:B26F8CA7:";
  reg [7:0] actual[0:N-1];
  reg [7:0] target;
  reg [31:0] ticks;
  integer i,b,nibble;
  initial begin
    #1000; rstn=1;
    wait (leds===6'b101010);
    wait (leds===6'b010101); // success: computed digest matches
    for (i=0;i<N;i=i+1) begin
      @(negedge tx);
      #4340;
      if (tx!==0) $fatal(1,"W01_PICO_UART_START: byte=%0d",i);
      actual[i]=8'd0;
      for (b=0;b<8;b=b+1) begin
        #8680;
        if (tx!==0 && tx!==1) $fatal(1,"W01_PICO_UNRESOLVED_BIT");
        actual[i][b]=tx;
      end
      #8680;
      if (tx!==1) $fatal(1,"W01_PICO_UART_STOP: byte=%0d",i);
    end
    for(i=0;i<13;i=i+1)begin
      target=PREFIX[8*(13-i)-1 -: 8];
      if (actual[i]!==target)
        $fatal(1,"W01_PICO_DIGEST_BYTE: pos=%0d got=0x%02h exp=0x%02h",i,actual[i],target);
    end
    ticks=32'd0;
    for(i=13;i<21;i=i+1)begin
      if (actual[i]>="0" && actual[i]<="9") nibble=actual[i]-"0";
      else if (actual[i]>="A" && actual[i]<="F") nibble=actual[i]-"A"+10;
      else $fatal(1,"W01_PICO_CYCLE_NOT_HEX: pos=%0d 0x%02h",i,actual[i]);
      ticks=(ticks<<4)|nibble;
    end
    if (actual[21]!==8'h0d || actual[22]!==8'h0a)
      $fatal(1,"W01_PICO_CRLF_MISSING");
    if (ticks<100 || ticks>1000000)
      $fatal(1,"W01_PICO_CYCLE_OUT_OF_RANGE: %0d",ticks);
    if (dut.trap!==0)
      $fatal(1,"W01_PICO_TRAP");
    $display("W01_PICO_SIM_PASS digest=B26F8CA7 cycles=%0d bytes=23",ticks);
    $finish;
  end
  initial begin
    #25000000;
    $fatal(1,"W01_PICO_SIM_TIMEOUT: 25ms");
  end
endmodule
