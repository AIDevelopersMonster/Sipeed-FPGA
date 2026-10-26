`timescale 1ns/1ps
module tb_lab062_pico;
reg clk=0,rstn=0,rx=1;
always #18.518 clk=~clk;
wire tx;wire [5:0] leds;
lab062_pico_soc dut(.clk_i(clk),.rstn_i(rstn),.uart0_rxd_i(rx),.uart0_txd_o(tx),.led_n_o(leds));
localparam LEN=16;
localparam [LEN*8-1:0] EXPECT="PICORV32 READY\r\n";
integer i,b;
reg [7:0] got,want;
initial begin
 #1000;rstn=1;
 wait(leds===6'b101010);
 for(i=0;i<LEN;i=i+1)begin
  @(negedge tx);
  #4340;
  if(tx!==0)$fatal(1,"start bit %0d",i);
  got=0;
  for(b=0;b<8;b=b+1)begin
   #8680;
   got[b]=tx;
  end
  #8680;
  if(tx!==1)$fatal(1,"stop bit %0d",i);
  want=EXPECT[8*(LEN-i)-1 -:8];
  if(got!==want)$fatal(1,"UART byte %0d got=%h wanted=%h",i,got,want);
 end
 wait(leds===6'b010101);
 if(dut.trap!==0)$fatal(1,"CPU trap");
 $display("LAB062_PICORV32_UART_GPIO_TB_PASS: 16 UART bytes; GPIO two patterns; real PicoRV32");
 $finish;
end
initial begin #5000000;$fatal(1,"LAB062_SIM_TIMEOUT");end
endmodule
