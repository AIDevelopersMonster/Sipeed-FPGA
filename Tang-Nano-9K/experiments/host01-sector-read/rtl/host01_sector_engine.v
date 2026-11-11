// HOST-01 host/SD streaming protocol engine. No UART or SPI RTL in this module.
// Request A5 01 LBA[4 LE] CRC16[2 LE]. Response 5A 81 STATUS LBA[4 LE]
// [512 data bytes on STATUS=00] CRC16[2 LE]; polynomial 1021, init FFFF.
module host01_sector_engine #(
 parameter integer RX_TIMEOUT_CYCLES=27000000,
 parameter integer SD_TIMEOUT_CYCLES=162000000
)(
 input wire clk,input wire reset_n,
 input wire rx_valid,output wire rx_ready,input wire [7:0] rx_data,
 output wire tx_valid,input wire tx_ready,output wire [7:0] tx_data,
 output reg sd_start,output reg [31:0] sd_lba,
 input wire sd_busy,input wire sd_done,input wire [7:0] sd_error,
 output reg [8:0] sd_peek_addr,input wire [7:0] sd_peek_data
);
 localparam [3:0] IDLE=0,RX=1,SD_START=2,SD_WAIT=3,
  HEADER=4,PREFETCH=5,PREFETCH_WAIT=6,DATA=7,CRC_LO=8,CRC_HI=9;
 reg [3:0] state;
 reg [2:0] rx_index,header_index;
 reg [31:0] lba_temp;
 reg [15:0] rx_crc,tx_crc,final_crc;
 reg [7:0] status;
 reg [8:0] data_index;
 reg [31:0] timer;
 wire [15:0] rx_crc_next,tx_crc_next;
 wire [7:0] send_data;
 crc16_ccitt_byte u_rx_crc(.crc_in(rx_crc),.byte_in(rx_data),.crc_out(rx_crc_next));
 crc16_ccitt_byte u_tx_crc(.crc_in(tx_crc),.byte_in(send_data),.crc_out(tx_crc_next));
 assign rx_ready=(state==IDLE || state==RX);
 function [7:0] response_header;
 input [2:0] idx;
 input [7:0] err;
 input [31:0] lba;
 begin case(idx)
  0:response_header=8'h5a;
  1:response_header=8'h81;
  2:response_header=err;
  3:response_header=lba[7:0];
  4:response_header=lba[15:8];
  5:response_header=lba[23:16];
  6:response_header=lba[31:24];
  default:response_header=8'h00;
 endcase end
 endfunction
 assign send_data=(state==HEADER)?response_header(header_index,status,sd_lba):
                  (state==DATA)?sd_peek_data:
                  (state==CRC_LO)?final_crc[7:0]:final_crc[15:8];
 assign tx_valid=(state==HEADER || state==DATA || state==CRC_LO || state==CRC_HI);
 assign tx_data=send_data;
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin
   state<=IDLE;rx_index<=0;header_index<=0;lba_temp<=0;rx_crc<=16'hffff;
   tx_crc<=16'hffff;final_crc<=0;status<=0;data_index<=0;timer<=0;
   sd_start<=0;sd_lba<=0;sd_peek_addr<=0;
  end else begin
   sd_start<=0;
   case(state)
   IDLE:if(rx_valid && rx_ready && rx_data==8'ha5)begin
    rx_crc<=16'h04bf; // CCITT-FALSE update(FFFF, A5)
    rx_index<=1;lba_temp<=0;timer<=0;state<=RX;
   end
   RX:if(rx_valid && rx_ready)begin
    timer<=0;
    case(rx_index)
     1:if(rx_data==8'h01)begin rx_crc<=rx_crc_next;rx_index<=2;end
       else state<=IDLE;
     2,3,4,5:begin
      case(rx_index)
       2:lba_temp[7:0]<=rx_data;
       3:lba_temp[15:8]<=rx_data;
       4:lba_temp[23:16]<=rx_data;
       5:lba_temp[31:24]<=rx_data;
      endcase
      rx_crc<=rx_crc_next;rx_index<=rx_index+1'b1;
     end
     6:if(rx_data==rx_crc[7:0])rx_index<=7;else state<=IDLE;
     7:if(rx_data==rx_crc[15:8])begin sd_lba<=lba_temp;state<=SD_START;timer<=0;end
       else state<=IDLE;
     default:state<=IDLE;
    endcase
   end else if(timer>=RX_TIMEOUT_CYCLES-1)state<=IDLE;
   else timer<=timer+1'b1;
   SD_START:if(!sd_busy)begin sd_start<=1;timer<=0;state<=SD_WAIT;end
   SD_WAIT:if(sd_done)begin status<=sd_error;tx_crc<=16'hffff;header_index<=0;state<=HEADER;end
    else if(timer>=SD_TIMEOUT_CYCLES-1)begin status<=8'hfd;tx_crc<=16'hffff;header_index<=0;state<=HEADER;end
    else timer<=timer+1'b1;
   HEADER:if(tx_valid&&tx_ready)begin
    tx_crc<=tx_crc_next;
    if(header_index==6)begin
     if(status==0)begin data_index<=0;sd_peek_addr<=0;state<=PREFETCH;end
     else begin final_crc<=tx_crc_next;state<=CRC_LO;end
    end else header_index<=header_index+1'b1;
   end
   // Two-cycle guard: sd_peek_data is registered BSRAM output.
   PREFETCH:state<=PREFETCH_WAIT;
   PREFETCH_WAIT:state<=DATA;
   DATA:if(tx_valid&&tx_ready)begin
    tx_crc<=tx_crc_next;
    if(data_index==9'd511)begin final_crc<=tx_crc_next;state<=CRC_LO;end
    else begin data_index<=data_index+1'b1;sd_peek_addr<=data_index+1'b1;state<=PREFETCH;end
   end
   CRC_LO:if(tx_valid&&tx_ready)state<=CRC_HI;
   CRC_HI:if(tx_valid&&tx_ready)state<=IDLE;
   default:state<=IDLE;
   endcase
  end
 end
endmodule
