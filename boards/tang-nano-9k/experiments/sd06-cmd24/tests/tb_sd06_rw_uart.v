// Complete PC-UART -> RTL bridge -> mock CMD17/CMD24 -> UART loop.
// Real SD-05 UART RX/TX and REAL SD-06 merged top. Simulated SD engines.
// No actual SD card, SPI bus, FPGA programming or hardware write.
// 27 MHz fabric clock, 2.7M baud in testbench for manageable simulation.
// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module lab05_sd_read_sector #(parameter integer HALF_PERIOD=64,
 parameter integer STARTUP_CYCLES=27000)(
 input wire clk,reset_n,start,input wire [31:0] read_lba,input wire sd_miso,
 output wire sd_sck,sd_mosi,sd_cs_n,
 output reg busy,done,initialized,output reg [7:0] error_code,
 input wire [8:0] peek_addr,output reg [7:0] peek_data
);
 reg [7:0] sector[0:511];
 reg [7:0] inject_error;
 reg [3:0] delay_count;
 integer read_count;
 integer k;
 initial begin
   inject_error=0;
   for(k=0;k<512;k=k+1) sector[k]=k[7:0]^8'ha5;
 end
 assign sd_sck=0,sd_mosi=1,sd_cs_n=1;
 always @(posedge clk) peek_data<=sector[peek_addr];
 always @(posedge clk or negedge reset_n)begin
   if(!reset_n)begin
     busy<=0;done<=0;initialized<=0;error_code<=0;
     delay_count<=0;read_count<=0;
   end else begin
     done<=0;
     if(start && !busy)begin
       busy<=1;delay_count<=4;read_count<=read_count+1;
     end else if(busy)begin
       if(delay_count!=0)delay_count<=delay_count-1'b1;
       else begin
         busy<=0;done<=1;initialized<=1;
         error_code<=inject_error;
       end
     end
   end
 end
endmodule

module sd06_cmd24_engine #(parameter integer HALF_PERIOD=64,
 parameter integer MAX_R1_POLLS=32,MAX_RESP_POLLS=8,
 parameter integer MAX_BUSY_BYTES=8192)(
 input wire clk,reset_n,load_valid,input wire [8:0] load_addr,
 input wire [7:0] load_byte,input wire start,card_ready,authorized,
 input wire [31:0] request_lba,approved_lba,input wire sd_miso,
 output wire sd_sck,sd_mosi,output reg sd_cs_n,busy,done,
 output reg [7:0] error_code,output wire payload_ready
);
 reg [7:0] payload[0:511];
 reg [9:0] loaded;
 reg [3:0] delay_count;
 reg [7:0] inject_error;
 integer write_count;
 initial inject_error=0;
 assign sd_sck=0,sd_mosi=1;
 assign payload_ready=(loaded==512);
 always @(posedge clk or negedge reset_n)begin
   if(!reset_n)begin
     loaded<=0;busy<=0;done<=0;error_code<=0;
     sd_cs_n<=1;delay_count<=0;write_count<=0;
   end else begin
     done<=0;
     if(load_valid && !busy)begin
       if(loaded<512 && load_addr==loaded[8:0])begin
         payload[load_addr]<=load_byte;
         loaded<=loaded+1'b1;
       end else loaded<=0;
     end
     if(start && !busy)begin
       if(!card_ready || !authorized || !payload_ready ||
          request_lba==0 || request_lba!=approved_lba)begin
         error_code<=8'hf1;done<=1;
       end else begin
         busy<=1;sd_cs_n<=0;delay_count<=4;
         write_count<=write_count+1;
       end
     end else if(busy)begin
       if(delay_count!=0)delay_count<=delay_count-1'b1;
       else begin
         busy<=0;sd_cs_n<=1;done<=1;error_code<=inject_error;
       end
     end
   end
 end
endmodule

module tb_sd06_rw_uart;
 localparam integer BIT_CYCLES=10;
 localparam [31:0] SCRATCH=32'd17472;
 reg clk=0,reset_n=0,uart_rx=1,sd_miso=1;
 wire uart_tx,sd_sck,sd_mosi,sd_cs_n;
 wire [5:0] led_n;
 wire [7:0] monitor_byte;
 wire monitor_valid,monitor_error;
 reg [7:0] observed[0:8191];
 integer observed_count=0;
 integer cycles,idx,committed_count=0;
 reg corrupt_verify=0;
 reg [15:0] packet_crc;
 reg [7:0] xbyte;
 always #5 clk=~clk;
 sd06_rw_bridge_top #(.HALF_PERIOD(2),.STARTUP_CYCLES(10),
   .UART_BAUD(2700000),.WRITE_FIRST_LBA(SCRATCH),
   .WRITE_LAST_LBA(SCRATCH)) dut(
    .clk(clk),.reset_n(reset_n),.uart_rx(uart_rx),.sd_miso(sd_miso),
    .uart_tx(uart_tx),.sd_sck(sd_sck),.sd_mosi(sd_mosi),
    .sd_cs_n(sd_cs_n),.led_n(led_n)
 );
 sd05_uart_rx_8n1 #(.CLOCK_HZ(27000000),.BAUD(2700000))
   monitor(.clk(clk),.reset_n(reset_n),.rx(uart_tx),
     .data(monitor_byte),.valid(monitor_valid),
     .framing_error(monitor_error));
 always @(posedge clk)begin
   if(monitor_error)$fatal(1,"UART TX framing error");
   if(monitor_valid)begin
     if(observed_count==8192)$fatal(1,"UART RX capture overflow");
     observed[observed_count]<=monitor_byte;
     observed_count<=observed_count+1;
   end
   // Mock card mutation ONLY once mock writer has accepted CMD24.
   // The REAL merged controller must independently read back via CMD17.
   if(reset_n && dut.wr_done && dut.wr_error==0)begin
     committed_count<=committed_count+1;
     for(idx=0;idx<512;idx=idx+1)
       dut.u_reader.sector[idx]<=dut.u_writer.payload[idx];
     if(corrupt_verify)
       dut.u_reader.sector[19]<=8'h00; // deliberately corrupt one byte
   end
 end
 function [15:0] crc_next;
 input [15:0] previous;input [7:0] value;
 reg [15:0] c;integer b;
 begin
   c=previous^{value,8'h00};
   for(b=0;b<8;b=b+1)
     c=c[15]?({c[14:0],1'b0}^16'h1021):{c[14:0],1'b0};
   crc_next=c;
 end
 endfunction
 task send_byte;
 input [7:0] data;
 integer b;
 begin
   uart_rx=0;repeat(BIT_CYCLES)@(negedge clk);
   for(b=0;b<8;b=b+1)begin
     uart_rx=data[b];repeat(BIT_CYCLES)@(negedge clk);
   end
   uart_rx=1;repeat(BIT_CYCLES)@(negedge clk);
 end
 endtask
 task send_payload_byte;
 input [7:0] data;
 begin packet_crc=crc_next(packet_crc,data);send_byte(data);end
 endtask
 task send_header;
 input [7:0] op,seq;input [31:0] lba;
 begin
   packet_crc=16'hffff;
   send_payload_byte(8'ha5);send_payload_byte(op);
   send_payload_byte(seq);
   send_payload_byte(lba[7:0]);send_payload_byte(lba[15:8]);
   send_payload_byte(lba[23:16]);send_payload_byte(lba[31:24]);
 end
 endtask
 task send_read;
 input [7:0] seq;input [31:0] lba;input bad_crc;
 begin
   send_header(8'h52,seq,lba);
   send_byte(packet_crc[7:0]^(bad_crc?8'h01:8'h00));
   send_byte(packet_crc[15:8]);
 end
 endtask
 task send_write;
 input [7:0] seq;input [31:0] lba;
 input [7:0] old_xor,new_xor;input bad_crc;
 integer j;
 begin
   send_header(8'h57,seq,lba);
   for(j=0;j<512;j=j+1)send_payload_byte(j[7:0]^old_xor);
   for(j=0;j<512;j=j+1)send_payload_byte(j[7:0]^new_xor);
   send_byte(packet_crc[7:0]^(bad_crc?8'h01:8'h00));
   send_byte(packet_crc[15:8]);
 end
 endtask
 task wait_count;
 input integer target;
 integer count;
 begin
   count=0;
   while(observed_count<target && count<250000)begin
     @(negedge clk);count=count+1;
   end
   if(observed_count!=target)
     $fatal(1,"response bytes got %0d want %0d",observed_count,target);
 end
 endtask
 task check_reply_crc;
 input integer base,length;
 reg [15:0] c;integer j;
 begin
   c=16'hffff;
   for(j=base;j<base+length-2;j=j+1)c=crc_next(c,observed[j]);
   if(observed[base+length-2]!==c[7:0]||
      observed[base+length-1]!==c[15:8])
      $fatal(1,"reply CRC mismatch at offset %0d",base);
 end
 endtask
 task check_write_reply;
 input integer base;input [7:0] seq,code;input [31:0] lba;
 integer j;reg [7:0] want;
 begin
   if(observed[base]!==8'h5a||observed[base+1]!==8'h57||
      observed[base+2]!==seq||observed[base+7]!==code)
       $fatal(1,"write reply status mismatch: seq=%0d code=%h observed=%h",
            seq,code,observed[base+7]);
   for(j=0;j<4;j=j+1)begin
     want=(lba>>(j*8));
     if(observed[base+3+j]!==want)$fatal(1,"write echo LBA mismatch");
   end
   check_reply_crc(base,10);
 end
 endtask
 task check_read_reply;
 input integer base;input [7:0] seq,content_xor;input [31:0] lba;
 integer j;reg [7:0] want;
 begin
   if(observed[base]!==8'h5a||observed[base+1]!==8'h44||
      observed[base+2]!==seq||observed[base+7]!==0||
      observed[base+8]!==0)$fatal(1,"read reply header mismatch");
   for(j=0;j<4;j=j+1)begin
     want=lba>>(j*8);
     if(observed[base+3+j]!==want)$fatal(1,"read LBA echo mismatch");
   end
   for(j=0;j<512;j=j+1)begin
     want=j[7:0]^content_xor;
     if(observed[base+9+j]!==want)
       $fatal(1,"read sector byte %0d mismatch got=%h expected=%h",
          j,observed[base+9+j],want);
   end
   check_reply_crc(base,523);
 end
 endtask

 initial begin
   repeat(12)@(negedge clk);reset_n=1;
   repeat(25)@(negedge clk);
   send_read(8'd1,SCRATCH,0);
   wait_count(523);
   check_read_reply(0,8'd1,8'ha5,SCRATCH);
   $display("SD06_RW_UART_READ_PASS: CMD17 byte-exact 512 + CRC");

   send_write(8'd2,SCRATCH,8'ha5,8'h5a,0);
   wait_count(533);
   check_write_reply(523,8'd2,8'h00,SCRATCH);
   if(committed_count!=1)$fatal(1,"CMD24 commit missing");
   $display("SD06_RW_UART_WRITE_PASS: old 512 matched, CMD24, verify 512");

   send_read(8'd3,SCRATCH,0);
   wait_count(1056);
   check_read_reply(533,8'd3,8'h5a,SCRATCH);
   $display("SD06_RW_UART_READBACK_PASS: written sector visible via CMD17");

   send_write(8'd4,SCRATCH,8'ha5,8'h3c,0);
   wait_count(1066);
   check_write_reply(1056,8'd4,8'hf9,SCRATCH);
   if(committed_count!=1)$fatal(1,"stale preimage wrote card!");
   $display("SD06_RW_UART_PREIMAGE_GUARD_PASS");

   send_write(8'd5,SCRATCH,8'h5a,8'h3c,1);
   wait_count(1076);
   check_write_reply(1066,8'd5,8'hf7,SCRATCH);
   if(committed_count!=1)$fatal(1,"bad frame CRC wrote card!");
   $display("SD06_RW_UART_CRC_GUARD_PASS");

   send_write(8'd6,SCRATCH+32'd1,8'h5a,8'h3c,0);
   wait_count(1086);
   check_write_reply(1076,8'd6,8'hf1,SCRATCH+32'd1);
   if(committed_count!=1)$fatal(1,"unauthorized LBA wrote card!");
   $display("SD06_RW_UART_LBA_GUARD_PASS");

   dut.u_writer.inject_error=8'hf4;
   send_write(8'd7,SCRATCH,8'h5a,8'h3c,0);
   wait_count(1096);
   check_write_reply(1086,8'd7,8'hf4,SCRATCH);
   if(committed_count!=1)$fatal(1,"rejected CMD24 changed card");
   dut.u_writer.inject_error=0;
   $display("SD06_RW_UART_CMD24_FAILURE_PASS");

   corrupt_verify=1;
   send_write(8'd8,SCRATCH,8'h5a,8'h3c,0);
   wait_count(1106);
   check_write_reply(1096,8'd8,8'hfa,SCRATCH);
   if(committed_count!=2)$fatal(1,"expected second mock write");
   $display("SD06_RW_UART_VERIFY_FAILURE_PASS");
   repeat(120)@(negedge clk);
   if(observed_count!=1106)$fatal(1,"unexpected trailing reply");
   $display("SD06_RW_UART_INTEGRATION_PASS: mock SD only");
   $finish;
 end
 initial begin
   #20000000;$fatal(1,"global SD RW UART simulation timeout");
 end
endmodule
