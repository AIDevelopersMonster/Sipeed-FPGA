// SD06-B byte-level SPI mock: no SD card, no COM port, no bitstream.
`timescale 1ns/1ps
module lab05_spi_byte #(parameter integer HALF_PERIOD=64)(
input wire clk,reset_n,start,input wire [7:0] tx_data,input wire miso,
output reg sck,mosi,busy,done,output reg [7:0] rx_data
);
  integer index,scenario;
  reg [2:0] remaining;
  reg [7:0] reply;
  reg [15:0] crc;
  integer k;
  function [15:0] next_crc;
    input [15:0] old; input [7:0] b;
    reg [15:0] c; integer n;
    begin
      c=old^{b,8'h00};
      for(n=0;n<8;n=n+1)c=c[15]?({c[14:0],1'b0}^16'h1021):{c[14:0],1'b0};
      next_crc=c;
    end
  endfunction
  always @(posedge clk or negedge reset_n)begin
    if(!reset_n)begin
      sck<=0;mosi<=1;busy<=0;done<=0;rx_data<=8'hff;
      index<=0;remaining<=0;reply<=8'hff;crc<=0;
    end else begin
      done<=0;
      if(!busy && start)begin
        if(index==0 && tx_data!==8'hff)$fatal(1,"missing gap");
        if(index==1 && tx_data!==8'h58)$fatal(1,"wrong CMD24 opcode");
        if(index==2 && tx_data!==8'h00)$fatal(1,"wrong LBA high");
        if(index==3 && tx_data!==8'h00)$fatal(1,"wrong LBA mid-high");
        if(index==4 && tx_data!==8'h01)$fatal(1,"wrong LBA mid-low");
        if(index==5 && tx_data!==8'hf4)$fatal(1,"wrong LBA low");
        if(index==6 && tx_data!==8'h01)$fatal(1,"wrong command CRC");
        if(index==9 && scenario!=1 && scenario!=7 && tx_data!==8'hfe)
          $fatal(1,"missing FE token");
        if(index>=10 && index<=521 && scenario!=1 && scenario!=7)begin
          if(tx_data!==((index-10)&8'hff))$fatal(1,"payload mismatch at %0d",index-10);
          crc<=next_crc(crc,tx_data);
        end
        if(index==522 && scenario!=1 && scenario!=7 && tx_data!==crc[15:8])
          $fatal(1,"CRC16 high mismatch");
        if(index==523 && scenario!=1 && scenario!=7 && tx_data!==crc[7:0])
          $fatal(1,"CRC16 low mismatch");
        if(index>=524 && tx_data!==8'hff)$fatal(1,"response clocks not FF");
        reply<=8'hff;
        case(scenario)
          0:begin
            if(index==7)reply<=8'h00;
            if(index==524)reply<=8'h05;
            if(index==525 || index==526)reply<=8'h00;
          end
          1:if(index==7)reply<=8'h04;
          2:begin
            if(index==7)reply<=8'h00;
            if(index==524)reply<=8'h0b;
          end
          3:if(index==7)reply<=8'h00;
          4:begin
            if(index==7)reply<=8'h00;
            if(index==524)reply<=8'h05;
            if(index>=525)reply<=8'h00;
          end
          7:begin end
          8:begin
            if(index==7)reply<=8'h00;
            if(index==525)reply<=8'h05;
            if(index==526)reply<=8'h00;
          end
        endcase
        busy<=1;remaining<=2;index<=index+1;
      end else if(busy)begin
        if(remaining!=0)remaining<=remaining-1'b1;
        else begin busy<=0;done<=1;rx_data<=reply;end
      end
    end
  end
endmodule

module tb;
  reg clk=0,reset_n=0,load_valid=0,start=0,card_ready=0,authorized=0;
  reg [8:0] load_addr=0;
  reg [7:0] load_byte=0;
  reg [31:0] request_lba=500,approved_lba=500;
  wire sd_sck,sd_mosi,sd_cs_n,busy,done,payload_ready;
  wire [7:0] error_code;
  integer i,cycles;
  always #5 clk=~clk;
  sd06_cmd24_engine #(.HALF_PERIOD(2),.MAX_R1_POLLS(3),
    .MAX_RESP_POLLS(3),.MAX_BUSY_BYTES(3)) dut(
    .clk(clk),.reset_n(reset_n),.load_valid(load_valid),
    .load_addr(load_addr),.load_byte(load_byte),.start(start),
    .card_ready(card_ready),.authorized(authorized),
    .request_lba(request_lba),.approved_lba(approved_lba),
    .sd_miso(1'b1),.sd_sck(sd_sck),.sd_mosi(sd_mosi),
    .sd_cs_n(sd_cs_n),.busy(busy),.done(done),
    .error_code(error_code),.payload_ready(payload_ready)
  );
  task reset_case;
    input integer sc;
    begin
      reset_n=0;start=0;load_valid=0;card_ready=0;authorized=0;
      repeat(6)@(negedge clk);
      dut.u_spi.scenario=sc;
      reset_n=1;
      repeat(6)@(negedge clk);
    end
  endtask
  task stage;
    integer j;
    begin
      for(j=0;j<512;j=j+1)begin
        load_valid=1;load_addr=j;load_byte=j[7:0];
        @(negedge clk);
      end
      load_valid=0;repeat(3)@(negedge clk);
      if(!payload_ready)$fatal(1,"payload not loaded");
    end
  endtask
  task kickoff;
    begin
      card_ready=1;authorized=1;start=1;
      @(negedge clk);start=0;
    end
  endtask
  task expect_result;
    input [7:0] expected_error;
    input integer bytes_expected;
    begin
      cycles=0;
      while(!done && cycles<100000)begin
        @(negedge clk);cycles=cycles+1;
      end
      if(!done)$fatal(1,"simulation timeout");
      if(error_code!==expected_error)$fatal(1,"error %h expected %h",error_code,expected_error);
      if(dut.u_spi.index!==bytes_expected)$fatal(1,"SPI count %0d expected %0d",dut.u_spi.index,bytes_expected);
      if(!sd_cs_n)$fatal(1,"SD CS not released");
      @(negedge clk);
    end
  endtask
  initial begin
    reset_case(0);stage();kickoff();expect_result(8'h00,529);
    $display("SD06_MOCK_WRITE_ACCEPTED_PASS");
    reset_case(1);stage();kickoff();expect_result(8'hf2,9);
    $display("SD06_MOCK_R1_REJECT_PASS");
    reset_case(2);stage();kickoff();expect_result(8'hf4,526);
    $display("SD06_MOCK_DATA_REJECT_PASS");
    reset_case(3);stage();kickoff();expect_result(8'hf5,528);
    $display("SD06_MOCK_RESPONSE_TIMEOUT_PASS");
    reset_case(4);stage();kickoff();expect_result(8'hf6,529);
    $display("SD06_MOCK_BUSY_TIMEOUT_PASS");
    reset_case(7);stage();kickoff();expect_result(8'hf3,11);
    $display("SD06_MOCK_R1_TIMEOUT_PASS");
    reset_case(8);stage();kickoff();expect_result(8'h00,529);
    $display("SD06_MOCK_DELAYED_RESPONSE_PASS");
    reset_case(0);stage();
    card_ready=0;authorized=1;start=1;@(negedge clk);start=0;
    if(!done||error_code!==8'hf1||dut.u_spi.index!==0)$fatal(1,"no-card guard");
    reset_case(0);stage();
    card_ready=1;authorized=0;start=1;@(negedge clk);start=0;
    if(!done||error_code!==8'hf1||dut.u_spi.index!==0)$fatal(1,"authorization guard");
    reset_case(0);stage();
    approved_lba=501;card_ready=1;authorized=1;start=1;
    @(negedge clk);start=0;
    if(!done||error_code!==8'hf1||dut.u_spi.index!==0)$fatal(1,"LBA guard");
    $display("SD06_CMD24_BYTE_MODEL_ALL_PASS: offline mock only");
    $finish;
  end
  initial begin
    #200000000;$fatal(1,"global timeout");
  end
endmodule
