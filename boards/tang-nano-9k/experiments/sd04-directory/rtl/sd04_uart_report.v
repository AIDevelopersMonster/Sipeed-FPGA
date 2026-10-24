// SD-04.2 UART reporting engine, one printable record per request.
// All reported geometry/entries originate in the top-level scanner and parser.
// Hex fields use fixed widths; no variable-width decimal arithmetic.
// No SD writes, no embedded processor. Verilog-2005.
module sd04_uart_report #(
 parameter integer CLOCK_HZ=27000000,
 parameter integer BAUD=115200
)(
 input wire clk,input wire reset_n,input wire send,
 input wire [2:0] msg_type, // 0 geometry,1 entry,2 summary,3 scan error,4 root read error
 input wire [31:0] root_lba,vol_lba,fat_lba,
 input wire [7:0] err,code,idx,attr,nfiles,ndirs,nlfn,nskip,stop,
 input wire [3:0] kind,
 input wire [87:0] name_raw,
 input wire [31:0] cluster,size,
 output wire uart_tx,output reg busy,output reg done
);
 reg tx_start;
 reg [7:0] tx_data;
 wire tx_busy;
 uart_tx_8n1 #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) u_tx(
 .clk(clk),.reset_n(reset_n),.start(tx_start),.data(tx_data),
 .tx(uart_tx),.busy(tx_busy)
 );
 function [7:0] hex_char;
 input [3:0] nib;
 begin
   hex_char=nib<10?8'd48+{4'd0,nib}:8'd55+{4'd0,nib};
 end
 endfunction
 function [7:0] print_char;
 input [7:0] c;
 begin
   if(c>=8'h20 && c<=8'h7e)print_char=c;
   else print_char=8'h3f; // non-ASCII/unsafe bytes are shown as '?'
 end
 endfunction
 function [7:0] kind_char;
 input [3:0] k;
 begin
   case(k)
    4'd1:kind_char="F"; // short file
    4'd2:kind_char="D"; // subdirectory
    4'd3:kind_char="L"; // LFN fragment, not decoded
    4'd4:kind_char="X"; // deleted
    4'd5:kind_char="E"; // end
    4'd6:kind_char="V"; // volume label
    default:kind_char="?";
   endcase
 end
 endfunction
 reg [2:0] selected;
 reg [6:0] pos,last_pos;
 reg [2:0] state;
 localparam [2:0] IDLE=0,LOAD=1,WAIT_TX_BUSY=2,WAIT_TX_IDLE=3;
 function [6:0] last_index;
 input [2:0] t;
 begin
   case(t)
    3'd0:last_index=7'd50;
    3'd1:last_index=7'd63;
    3'd2:last_index=7'd47;
    3'd3:last_index=7'd25;
    3'd4:last_index=7'd30;
    default:last_index=0;
   endcase
 end
 endfunction
 function [7:0] char_at;
 input [2:0] t;
 input [6:0] pos;
 input [31:0] root_lba,vol_lba,fat_lba,cluster,size;
 input [7:0] err,code,idx,attr,nfiles,ndirs,nlfn,nskip,stop;
 input [3:0] kind;
 input [87:0] name_raw;
 begin
  char_at=8'h20;
  case(t)
          3'd0:begin
            case(pos)
              7'd0: char_at=8'h53;
              7'd1: char_at=8'h44;
              7'd2: char_at=8'h30;
              7'd3: char_at=8'h34;
              7'd4: char_at=8'h20;
              7'd5: char_at=8'h52;
              7'd6: char_at=8'h4f;
              7'd7: char_at=8'h4f;
              7'd8: char_at=8'h54;
              7'd9: char_at=8'h3d;
              7'd10: char_at=hex_char(root_lba[31:28]);
              7'd11: char_at=hex_char(root_lba[27:24]);
              7'd12: char_at=hex_char(root_lba[23:20]);
              7'd13: char_at=hex_char(root_lba[19:16]);
              7'd14: char_at=hex_char(root_lba[15:12]);
              7'd15: char_at=hex_char(root_lba[11:8]);
              7'd16: char_at=hex_char(root_lba[7:4]);
              7'd17: char_at=hex_char(root_lba[3:0]);
              7'd18: char_at=8'h20;
              7'd19: char_at=8'h56;
              7'd20: char_at=8'h4f;
              7'd21: char_at=8'h4c;
              7'd22: char_at=8'h3d;
              7'd23: char_at=hex_char(vol_lba[31:28]);
              7'd24: char_at=hex_char(vol_lba[27:24]);
              7'd25: char_at=hex_char(vol_lba[23:20]);
              7'd26: char_at=hex_char(vol_lba[19:16]);
              7'd27: char_at=hex_char(vol_lba[15:12]);
              7'd28: char_at=hex_char(vol_lba[11:8]);
              7'd29: char_at=hex_char(vol_lba[7:4]);
              7'd30: char_at=hex_char(vol_lba[3:0]);
              7'd31: char_at=8'h20;
              7'd32: char_at=8'h46;
              7'd33: char_at=8'h41;
              7'd34: char_at=8'h54;
              7'd35: char_at=8'h3d;
              7'd36: char_at=hex_char(fat_lba[31:28]);
              7'd37: char_at=hex_char(fat_lba[27:24]);
              7'd38: char_at=hex_char(fat_lba[23:20]);
              7'd39: char_at=hex_char(fat_lba[19:16]);
              7'd40: char_at=hex_char(fat_lba[15:12]);
              7'd41: char_at=hex_char(fat_lba[11:8]);
              7'd42: char_at=hex_char(fat_lba[7:4]);
              7'd43: char_at=hex_char(fat_lba[3:0]);
              7'd44: char_at=8'h20;
              7'd45: char_at=8'h45;
              7'd46: char_at=8'h3d;
              7'd47: char_at=hex_char(err[7:4]);
              7'd48: char_at=hex_char(err[3:0]);
              7'd49: char_at=8'h0d;
              7'd50: char_at=8'h0a;
              default:char_at=8'h20;
            endcase
          end
          3'd1:begin
            case(pos)
              7'd0: char_at=8'h53;
              7'd1: char_at=8'h44;
              7'd2: char_at=8'h30;
              7'd3: char_at=8'h34;
              7'd4: char_at=8'h20;
              7'd5: char_at=8'h49;
              7'd6: char_at=8'h44;
              7'd7: char_at=8'h58;
              7'd8: char_at=8'h3d;
              7'd9: char_at=hex_char(idx[7:4]);
              7'd10: char_at=hex_char(idx[3:0]);
              7'd11: char_at=8'h20;
              7'd12: char_at=8'h4b;
              7'd13: char_at=8'h3d;
              7'd14: char_at=kind_char(kind);
              7'd15: char_at=8'h20;
              7'd16: char_at=8'h4e;
              7'd17: char_at=8'h41;
              7'd18: char_at=8'h4d;
              7'd19: char_at=8'h45;
              7'd20: char_at=8'h3d;
              7'd21: char_at=print_char(name_raw[87:80]);
              7'd22: char_at=print_char(name_raw[79:72]);
              7'd23: char_at=print_char(name_raw[71:64]);
              7'd24: char_at=print_char(name_raw[63:56]);
              7'd25: char_at=print_char(name_raw[55:48]);
              7'd26: char_at=print_char(name_raw[47:40]);
              7'd27: char_at=print_char(name_raw[39:32]);
              7'd28: char_at=print_char(name_raw[31:24]);
              7'd29: char_at=8'h2e;
              7'd30: char_at=print_char(name_raw[23:16]);
              7'd31: char_at=print_char(name_raw[15:8]);
              7'd32: char_at=print_char(name_raw[7:0]);
              7'd33: char_at=8'h20;
              7'd34: char_at=8'h41;
              7'd35: char_at=8'h3d;
              7'd36: char_at=hex_char(attr[7:4]);
              7'd37: char_at=hex_char(attr[3:0]);
              7'd38: char_at=8'h20;
              7'd39: char_at=8'h43;
              7'd40: char_at=8'h4c;
              7'd41: char_at=8'h3d;
              7'd42: char_at=hex_char(cluster[31:28]);
              7'd43: char_at=hex_char(cluster[27:24]);
              7'd44: char_at=hex_char(cluster[23:20]);
              7'd45: char_at=hex_char(cluster[19:16]);
              7'd46: char_at=hex_char(cluster[15:12]);
              7'd47: char_at=hex_char(cluster[11:8]);
              7'd48: char_at=hex_char(cluster[7:4]);
              7'd49: char_at=hex_char(cluster[3:0]);
              7'd50: char_at=8'h20;
              7'd51: char_at=8'h53;
              7'd52: char_at=8'h5a;
              7'd53: char_at=8'h3d;
              7'd54: char_at=hex_char(size[31:28]);
              7'd55: char_at=hex_char(size[27:24]);
              7'd56: char_at=hex_char(size[23:20]);
              7'd57: char_at=hex_char(size[19:16]);
              7'd58: char_at=hex_char(size[15:12]);
              7'd59: char_at=hex_char(size[11:8]);
              7'd60: char_at=hex_char(size[7:4]);
              7'd61: char_at=hex_char(size[3:0]);
              7'd62: char_at=8'h0d;
              7'd63: char_at=8'h0a;
              default:char_at=8'h20;
            endcase
          end
          3'd2:begin
            case(pos)
              7'd0: char_at=8'h53;
              7'd1: char_at=8'h44;
              7'd2: char_at=8'h30;
              7'd3: char_at=8'h34;
              7'd4: char_at=8'h20;
              7'd5: char_at=8'h45;
              7'd6: char_at=8'h4e;
              7'd7: char_at=8'h44;
              7'd8: char_at=8'h20;
              7'd9: char_at=8'h46;
              7'd10: char_at=8'h49;
              7'd11: char_at=8'h4c;
              7'd12: char_at=8'h45;
              7'd13: char_at=8'h3d;
              7'd14: char_at=hex_char(nfiles[7:4]);
              7'd15: char_at=hex_char(nfiles[3:0]);
              7'd16: char_at=8'h20;
              7'd17: char_at=8'h44;
              7'd18: char_at=8'h49;
              7'd19: char_at=8'h52;
              7'd20: char_at=8'h3d;
              7'd21: char_at=hex_char(ndirs[7:4]);
              7'd22: char_at=hex_char(ndirs[3:0]);
              7'd23: char_at=8'h20;
              7'd24: char_at=8'h4c;
              7'd25: char_at=8'h46;
              7'd26: char_at=8'h4e;
              7'd27: char_at=8'h3d;
              7'd28: char_at=hex_char(nlfn[7:4]);
              7'd29: char_at=hex_char(nlfn[3:0]);
              7'd30: char_at=8'h20;
              7'd31: char_at=8'h53;
              7'd32: char_at=8'h4b;
              7'd33: char_at=8'h49;
              7'd34: char_at=8'h50;
              7'd35: char_at=8'h3d;
              7'd36: char_at=hex_char(nskip[7:4]);
              7'd37: char_at=hex_char(nskip[3:0]);
              7'd38: char_at=8'h20;
              7'd39: char_at=8'h53;
              7'd40: char_at=8'h54;
              7'd41: char_at=8'h4f;
              7'd42: char_at=8'h50;
              7'd43: char_at=8'h3d;
              7'd44: char_at=hex_char(stop[7:4]);
              7'd45: char_at=hex_char(stop[3:0]);
              7'd46: char_at=8'h0d;
              7'd47: char_at=8'h0a;
              default:char_at=8'h20;
            endcase
          end
          3'd3:begin
            case(pos)
              7'd0: char_at=8'h53;
              7'd1: char_at=8'h44;
              7'd2: char_at=8'h30;
              7'd3: char_at=8'h34;
              7'd4: char_at=8'h20;
              7'd5: char_at=8'h53;
              7'd6: char_at=8'h43;
              7'd7: char_at=8'h41;
              7'd8: char_at=8'h4e;
              7'd9: char_at=8'h5f;
              7'd10: char_at=8'h45;
              7'd11: char_at=8'h52;
              7'd12: char_at=8'h52;
              7'd13: char_at=8'h3d;
              7'd14: char_at=hex_char(code[7:4]);
              7'd15: char_at=hex_char(code[3:0]);
              7'd16: char_at=8'h20;
              7'd17: char_at=8'h53;
              7'd18: char_at=8'h44;
              7'd19: char_at=8'h5f;
              7'd20: char_at=8'h45;
              7'd21: char_at=8'h3d;
              7'd22: char_at=hex_char(err[7:4]);
              7'd23: char_at=hex_char(err[3:0]);
              7'd24: char_at=8'h0d;
              7'd25: char_at=8'h0a;
              default:char_at=8'h20;
            endcase
          end
          3'd4:begin
            case(pos)
              7'd0: char_at=8'h53;
              7'd1: char_at=8'h44;
              7'd2: char_at=8'h30;
              7'd3: char_at=8'h34;
              7'd4: char_at=8'h20;
              7'd5: char_at=8'h52;
              7'd6: char_at=8'h4f;
              7'd7: char_at=8'h4f;
              7'd8: char_at=8'h54;
              7'd9: char_at=8'h5f;
              7'd10: char_at=8'h45;
              7'd11: char_at=8'h52;
              7'd12: char_at=8'h52;
              7'd13: char_at=8'h3d;
              7'd14: char_at=hex_char(err[7:4]);
              7'd15: char_at=hex_char(err[3:0]);
              7'd16: char_at=8'h20;
              7'd17: char_at=8'h4c;
              7'd18: char_at=8'h42;
              7'd19: char_at=8'h41;
              7'd20: char_at=8'h3d;
              7'd21: char_at=hex_char(root_lba[31:28]);
              7'd22: char_at=hex_char(root_lba[27:24]);
              7'd23: char_at=hex_char(root_lba[23:20]);
              7'd24: char_at=hex_char(root_lba[19:16]);
              7'd25: char_at=hex_char(root_lba[15:12]);
              7'd26: char_at=hex_char(root_lba[11:8]);
              7'd27: char_at=hex_char(root_lba[7:4]);
              7'd28: char_at=hex_char(root_lba[3:0]);
              7'd29: char_at=8'h0d;
              7'd30: char_at=8'h0a;
              default:char_at=8'h20;
            endcase
          end
    default:char_at=8'h3f;
  endcase
 end
 endfunction
 always @(posedge clk or negedge reset_n)begin
  if(!reset_n)begin
   tx_start<=0;tx_data<=0;busy<=0;done<=0;
   selected<=0;pos<=0;last_pos<=0;state<=IDLE;
  end else begin
   tx_start<=0;done<=0;
   case(state)
    IDLE:if(send)begin
     busy<=1;selected<=msg_type;
     last_pos<=last_index(msg_type);pos<=0;state<=LOAD;
    end
    LOAD:if(!tx_busy)begin
     tx_data<=char_at(selected,pos,root_lba,vol_lba,fat_lba,
       cluster,size,err,code,idx,attr,nfiles,ndirs,nlfn,nskip,stop,kind,name_raw);
     tx_start<=1;state<=WAIT_TX_BUSY;
    end
    WAIT_TX_BUSY:if(tx_busy)state<=WAIT_TX_IDLE;
    WAIT_TX_IDLE:if(!tx_busy)begin
     if(pos==last_pos)begin busy<=0;done<=1;state<=IDLE;end
     else begin pos<=pos+1'b1;state<=LOAD;end
    end
    default:state<=IDLE;
   endcase
  end
 end
endmodule
