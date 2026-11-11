// SD-04 isolated integration regression. Stubs model sync RAM, SD CMD17
// handshake, validated root LBA, UART busy protocol. No hardware claims.
`timescale 1ns/1ps
module sd03_volume_scanner(
 input clk,reset_n,start, output reg sd_start, output reg [31:0] sd_lba,
 input sd_busy,sd_done,input [7:0] sd_error,
 output reg [8:0] peek_addr,input [7:0] peek_data,
 output reg done,output reg [3:0] result,
 output reg [31:0] volume_lba,fat_lba,data_lba,root_lba,cluster_count
);
 reg [2:0] st;
 always @(posedge clk or negedge reset_n)
 if(!reset_n)begin st<=0;done<=0;result<=0;sd_start<=0;sd_lba<=0;peek_addr<=0;root_lba<=0;
 volume_lba<=0;fat_lba<=0;data_lba<=0;cluster_count<=0;end
 else begin
 sd_start<=0;done<=0;
 case(st)
 0:if(start)begin sd_start<=1;sd_lba<=0;st<=1;end
 1:if(sd_done)begin root_lba<=32'd17472;result<=1;st<=2;end
 2:begin done<=1;st<=3;end
 endcase
 end
endmodule
module lab05_sd_read_sector #(parameter HALF_PERIOD=64, STARTUP_CYCLES=27000)(
 input clk,reset_n,start,input [31:0] read_lba,input sd_miso,
 output sd_sck,sd_mosi,output sd_cs_n,
 output reg busy,done,initialized,output reg [7:0] error_code,
 input [8:0] peek_addr,output reg [7:0] peek_data
);
 reg [7:0] sector[0:511];
 reg [2:0] timer;
 integer i;
 assign sd_sck=0;assign sd_mosi=1;assign sd_cs_n=1;
 initial for(i=0;i<512;i=i+1)sector[i]=i[7:0]^8'hA5;
 always @(posedge clk)peek_data<=sector[peek_addr];
 always @(posedge clk or negedge reset_n)
 if(!reset_n)begin busy<=0;done<=0;initialized<=0;error_code<=0;timer<=0;end
 else begin
 done<=0;
 if(start&&!busy)begin busy<=1;timer<=3;end
 else if(busy)begin
 if(timer!=0)timer<=timer-1'b1;
 else begin busy<=0;done<=1;initialized<=1;error_code<=0;end
 end
 end
endmodule
module uart_tx_8n1 #(parameter CLOCK_HZ=27000000, BAUD=115200)(
 input clk,reset_n,start,input [7:0] data,output tx,output reg busy
);
 reg [2:0] countdown;
 integer count;
 reg [7:0] captured[0:1100];
 assign tx=1;
 initial count=0;
 always @(posedge clk or negedge reset_n)
 if(!reset_n)begin busy<=0;countdown<=0;count<=0;end
 else if(start&&!busy)begin
 captured[count]<=data;count<=count+1;busy<=1;countdown<=2;
 end else if(busy)begin
 if(countdown!=0)countdown<=countdown-1'b1;
 else busy<=0;
 end
endmodule
module tb_sd04_root_dump;
 reg clk=0, reset_n=0,sd_miso=1;
 wire sd_sck,sd_mosi,sd_cs_n,uart_tx;
 wire [5:0] led_n;
 integer cycles,i;
 reg [7:0] expected, hi, lo;
 sd04_root_dump_top dut(.clk(clk),.reset_n(reset_n),.sd_miso(sd_miso),
 .sd_sck(sd_sck),.sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),
 .uart_tx(uart_tx),.led_n(led_n));
 always #5 clk=~clk;
 function [7:0] hx;
 input [3:0] v;
 begin hx=v<10 ? 8'd48+v : 8'd55+v;end
 endfunction
 initial begin
 repeat(4)@(negedge clk);reset_n=1;
 cycles=0;
 while(dut.u_uart.count<1026 && cycles<50000)begin
 @(negedge clk);cycles=cycles+1;
 end
 if(cycles>=50000)$fatal(1,"timeout: UART incomplete");
 if(dut.u_uart.count!=1026)$fatal(1,"wrong byte count");
 for(i=0;i<512;i=i+1)begin
 expected=(i&255)^8'hA5;
 hi=dut.u_uart.captured[i*2];
 lo=dut.u_uart.captured[i*2+1];
 if(hi!==hx(expected[7:4]) || lo!==hx(expected[3:0]))
 $fatal(1,"byte %0d mismatch %h %h",i,hi,lo);
 end
 if(dut.u_uart.captured[1024]!==8'h0d ||
    dut.u_uart.captured[1025]!==8'h0a)$fatal(1,"missing CRLF");
 if(led_n!==6'b111110)$fatal(1,"LED success mismatch");
 repeat(40)@(negedge clk);
 if(dut.u_uart.count!==1026)$fatal(1,"extra UART bytes");
 $display("SD04_ROOT_DUMP_TB_PASS: 512 bytes, UART framing, no extra bytes");
 $finish;
 end
endmodule
