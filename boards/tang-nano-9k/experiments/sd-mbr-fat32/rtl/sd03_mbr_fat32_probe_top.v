// SD-03.4: Tang Nano 9K read-only MBR/FAT32 discovery probe.
// SDHC physical CMD17 -> one 512-byte BSRAM -> MBR/BPB scanner -> UART.
// No PicoRV32, FAT traversal, file reads or SD writes.
// PnR/STA and physical hardware acceptance have NOT yet occurred.
// Status format is NOT a generic "SD03 PASS": unsupported formats are valid
// classifications, not proof of an SDHC read fault.
// SPDX-License-Identifier: MIT
module sd03_mbr_fat32_probe_top #(
    parameter integer HALF_PERIOD=64,
    parameter integer STARTUP_CYCLES=27000,
    parameter integer UART_BAUD=115200
) (
    input wire clk,
    input wire reset_n,
    input wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output wire sd_cs_n,
    output wire uart_tx,
    output wire [5:0] led_n
);
    reg scanner_start;
    wire sd_start, sd_busy, sd_done, initialized;
    wire [31:0] sd_lba;
    wire [7:0] sd_error, peek_data;
    wire [8:0] peek_addr;
    wire scanner_done;
    wire [3:0] scanner_result;
    wire [31:0] scanner_vol,scanner_fat,scanner_data,scanner_root,scanner_clusters;
    lab05_sd_read_sector #(
        .HALF_PERIOD(HALF_PERIOD),
        .STARTUP_CYCLES(STARTUP_CYCLES)
    ) u_reader (
        .clk(clk),.reset_n(reset_n),.start(sd_start),.read_lba(sd_lba),
        .sd_miso(sd_miso),.sd_sck(sd_sck),.sd_mosi(sd_mosi),
        .sd_cs_n(sd_cs_n),.busy(sd_busy),.done(sd_done),
        .initialized(initialized),.error_code(sd_error),
        .peek_addr(peek_addr),.peek_data(peek_data)
    );
    sd03_volume_scanner u_scanner (
        .clk(clk),.reset_n(reset_n),.start(scanner_start),
        .sd_start(sd_start),.sd_lba(sd_lba),
        .sd_busy(sd_busy),.sd_done(sd_done),.sd_error(sd_error),
        .peek_addr(peek_addr),.peek_data(peek_data),
        .done(scanner_done),.result(scanner_result),
        .volume_lba(scanner_vol),.fat_lba(scanner_fat),
        .data_lba(scanner_data),.root_lba(scanner_root),
        .cluster_count(scanner_clusters)
    );
    reg uart_start;
    reg [7:0] uart_data;
    wire uart_busy;
    uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_uart (
        .clk(clk),.reset_n(reset_n),.start(uart_start),
        .data(uart_data),.tx(uart_tx),.busy(uart_busy)
    );

    reg [3:0] code_latched;
    reg [7:0] error_latched;
    reg [31:0] vol_latched,fat_latched,data_latched,root_latched,clusters_latched;
    reg [6:0] msg_pos;
    reg [2:0] state;
    reg [5:0] leds;
    assign led_n=leds;
    localparam [2:0] ST_BOOT=0,ST_WAIT=1,ST_SEND=2,
        ST_UART_BUSY=3,ST_UART_IDLE=4,ST_HALT=5;

    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            hex_char = nibble<4'd10 ? (8'd48+{4'd0,nibble})
                                    : (8'd55+{4'd0,nibble});
        end
    endfunction
    function [7:0] status_char;
        input [3:0] code;
        input [3:0] idx;
        begin
            status_char=8'h20;
            case(code)
            4'd1: case(idx)
                    4'd0: status_char=8'h4d;
                    4'd1: status_char=8'h42;
                    4'd2: status_char=8'h52;
                    4'd3: status_char=8'h5f;
                    4'd4: status_char=8'h46;
                    4'd5: status_char=8'h41;
                    4'd6: status_char=8'h54;
                    4'd7: status_char=8'h33;
                    4'd8: status_char=8'h32;
                    4'd9: status_char=8'h20;
                    4'd10: status_char=8'h20;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
            4'd2: case(idx)
                    4'd0: status_char=8'h53;
                    4'd1: status_char=8'h55;
                    4'd2: status_char=8'h50;
                    4'd3: status_char=8'h45;
                    4'd4: status_char=8'h52;
                    4'd5: status_char=8'h46;
                    4'd6: status_char=8'h4c;
                    4'd7: status_char=8'h4f;
                    4'd8: status_char=8'h50;
                    4'd9: status_char=8'h50;
                    4'd10: status_char=8'h59;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
            4'd3: case(idx)
                    4'd0: status_char=8'h47;
                    4'd1: status_char=8'h50;
                    4'd2: status_char=8'h54;
                    4'd3: status_char=8'h5f;
                    4'd4: status_char=8'h55;
                    4'd5: status_char=8'h4e;
                    4'd6: status_char=8'h53;
                    4'd7: status_char=8'h55;
                    4'd8: status_char=8'h50;
                    4'd9: status_char=8'h20;
                    4'd10: status_char=8'h20;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
            4'd4: case(idx)
                    4'd0: status_char=8'h4e;
                    4'd1: status_char=8'h4f;
                    4'd2: status_char=8'h5f;
                    4'd3: status_char=8'h46;
                    4'd4: status_char=8'h41;
                    4'd5: status_char=8'h54;
                    4'd6: status_char=8'h33;
                    4'd7: status_char=8'h32;
                    4'd8: status_char=8'h20;
                    4'd9: status_char=8'h20;
                    4'd10: status_char=8'h20;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
            4'd5: case(idx)
                    4'd0: status_char=8'h53;
                    4'd1: status_char=8'h44;
                    4'd2: status_char=8'h5f;
                    4'd3: status_char=8'h52;
                    4'd4: status_char=8'h45;
                    4'd5: status_char=8'h41;
                    4'd6: status_char=8'h44;
                    4'd7: status_char=8'h5f;
                    4'd8: status_char=8'h45;
                    4'd9: status_char=8'h52;
                    4'd10: status_char=8'h52;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
            4'd6: case(idx)
                    4'd0: status_char=8'h49;
                    4'd1: status_char=8'h4e;
                    4'd2: status_char=8'h56;
                    4'd3: status_char=8'h41;
                    4'd4: status_char=8'h4c;
                    4'd5: status_char=8'h49;
                    4'd6: status_char=8'h44;
                    4'd7: status_char=8'h5f;
                    4'd8: status_char=8'h42;
                    4'd9: status_char=8'h50;
                    4'd10: status_char=8'h42;
                    4'd11: status_char=8'h20;
                    default:status_char=8'h20;
                endcase
                default: status_char=8'h3f;
            endcase
        end
    endfunction
    // Fixed 99-byte record, last two bytes CR LF.
    // "SD03 RESULT=............ VOL=XXXXXXXX FAT=XXXXXXXX DATA=XXXXXXXX ROOT=XXXXXXXX CLUS=XXXXXXXX E=XX"
    // Data addresses are zero when the format has not been validated.
    function [7:0] report_char;
        input [6:0] pos;
        input [3:0] code;
        input [31:0] vol,fat,data_start,root,clusters;
        input [7:0] err;
        begin
            report_char=8'h20;
            case(pos)
            7'd0: report_char=8'h53;
            7'd1: report_char=8'h44;
            7'd2: report_char=8'h30;
            7'd3: report_char=8'h33;
            7'd4: report_char=8'h20;
            7'd5: report_char=8'h52;
            7'd6: report_char=8'h45;
            7'd7: report_char=8'h53;
            7'd8: report_char=8'h55;
            7'd9: report_char=8'h4c;
            7'd10: report_char=8'h54;
            7'd11: report_char=8'h3d;
            7'd12: report_char=status_char(code,4'd0);
            7'd13: report_char=status_char(code,4'd1);
            7'd14: report_char=status_char(code,4'd2);
            7'd15: report_char=status_char(code,4'd3);
            7'd16: report_char=status_char(code,4'd4);
            7'd17: report_char=status_char(code,4'd5);
            7'd18: report_char=status_char(code,4'd6);
            7'd19: report_char=status_char(code,4'd7);
            7'd20: report_char=status_char(code,4'd8);
            7'd21: report_char=status_char(code,4'd9);
            7'd22: report_char=status_char(code,4'd10);
            7'd23: report_char=status_char(code,4'd11);
            7'd24: report_char=8'h20;
            7'd25: report_char=8'h56;
            7'd26: report_char=8'h4f;
            7'd27: report_char=8'h4c;
            7'd28: report_char=8'h3d;
            7'd29: report_char=hex_char(vol[31:28]);
            7'd30: report_char=hex_char(vol[27:24]);
            7'd31: report_char=hex_char(vol[23:20]);
            7'd32: report_char=hex_char(vol[19:16]);
            7'd33: report_char=hex_char(vol[15:12]);
            7'd34: report_char=hex_char(vol[11:8]);
            7'd35: report_char=hex_char(vol[7:4]);
            7'd36: report_char=hex_char(vol[3:0]);
            7'd37: report_char=8'h20;
            7'd38: report_char=8'h46;
            7'd39: report_char=8'h41;
            7'd40: report_char=8'h54;
            7'd41: report_char=8'h3d;
            7'd42: report_char=hex_char(fat[31:28]);
            7'd43: report_char=hex_char(fat[27:24]);
            7'd44: report_char=hex_char(fat[23:20]);
            7'd45: report_char=hex_char(fat[19:16]);
            7'd46: report_char=hex_char(fat[15:12]);
            7'd47: report_char=hex_char(fat[11:8]);
            7'd48: report_char=hex_char(fat[7:4]);
            7'd49: report_char=hex_char(fat[3:0]);
            7'd50: report_char=8'h20;
            7'd51: report_char=8'h44;
            7'd52: report_char=8'h41;
            7'd53: report_char=8'h54;
            7'd54: report_char=8'h41;
            7'd55: report_char=8'h3d;
            7'd56: report_char=hex_char(data_start[31:28]);
            7'd57: report_char=hex_char(data_start[27:24]);
            7'd58: report_char=hex_char(data_start[23:20]);
            7'd59: report_char=hex_char(data_start[19:16]);
            7'd60: report_char=hex_char(data_start[15:12]);
            7'd61: report_char=hex_char(data_start[11:8]);
            7'd62: report_char=hex_char(data_start[7:4]);
            7'd63: report_char=hex_char(data_start[3:0]);
            7'd64: report_char=8'h20;
            7'd65: report_char=8'h52;
            7'd66: report_char=8'h4f;
            7'd67: report_char=8'h4f;
            7'd68: report_char=8'h54;
            7'd69: report_char=8'h3d;
            7'd70: report_char=hex_char(root[31:28]);
            7'd71: report_char=hex_char(root[27:24]);
            7'd72: report_char=hex_char(root[23:20]);
            7'd73: report_char=hex_char(root[19:16]);
            7'd74: report_char=hex_char(root[15:12]);
            7'd75: report_char=hex_char(root[11:8]);
            7'd76: report_char=hex_char(root[7:4]);
            7'd77: report_char=hex_char(root[3:0]);
            7'd78: report_char=8'h20;
            7'd79: report_char=8'h43;
            7'd80: report_char=8'h4c;
            7'd81: report_char=8'h55;
            7'd82: report_char=8'h53;
            7'd83: report_char=8'h3d;
            7'd84: report_char=hex_char(clusters[31:28]);
            7'd85: report_char=hex_char(clusters[27:24]);
            7'd86: report_char=hex_char(clusters[23:20]);
            7'd87: report_char=hex_char(clusters[19:16]);
            7'd88: report_char=hex_char(clusters[15:12]);
            7'd89: report_char=hex_char(clusters[11:8]);
            7'd90: report_char=hex_char(clusters[7:4]);
            7'd91: report_char=hex_char(clusters[3:0]);
            7'd92: report_char=8'h20;
            7'd93: report_char=8'h45;
            7'd94: report_char=8'h3d;
            7'd95: report_char=hex_char(err[7:4]);
            7'd96: report_char=hex_char(err[3:0]);
            7'd97: report_char=8'h0d;
            7'd98: report_char=8'h0a;
                default:report_char=8'h20;
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            scanner_start<=0;
            uart_start<=0;uart_data<=0;msg_pos<=0;
            code_latched<=0;error_latched<=0;
            vol_latched<=0;fat_latched<=0;data_latched<=0;
            root_latched<=0;clusters_latched<=0;
            leds<=6'b111111;state<=ST_BOOT;
        end else begin
            scanner_start<=0;uart_start<=0;
            case(state)
                ST_BOOT:begin
                    scanner_start<=1;
                    state<=ST_WAIT;
                end
                ST_WAIT:if(scanner_done)begin
                    code_latched<=scanner_result;
                    error_latched<=sd_error;
                    vol_latched<=scanner_vol;
                    fat_latched<=scanner_fat;
                    data_latched<=scanner_data;
                    root_latched<=scanner_root;
                    clusters_latched<=scanner_clusters;
                    msg_pos<=0;state<=ST_SEND;
                end
                ST_SEND:if(!uart_busy)begin
                    uart_data<=report_char(msg_pos,code_latched,vol_latched,
                        fat_latched,data_latched,root_latched,clusters_latched,error_latched);
                    uart_start<=1;
                    state<=ST_UART_BUSY;
                end
                ST_UART_BUSY:if(uart_busy)state<=ST_UART_IDLE;
                ST_UART_IDLE:if(!uart_busy)begin
                    if(msg_pos==7'd98)state<=ST_HALT;
                    else begin
                        msg_pos<=msg_pos+1'b1;
                        state<=ST_SEND;
                    end
                end
                ST_HALT:begin
                    // LED 0 = verified FAT32 (MBR or superfloppy).
                    // LED 1 = classified/unsupported format; remaining OFF.
                    // All six LEDs ON = SD read failure or internal fault.
                    if(code_latched==4'd1 || code_latched==4'd2)
                        leds<=6'b111110;
                    else if(code_latched==4'd3 || code_latched==4'd4 || code_latched==4'd6)
                        leds<=6'b111101;
                    else
                        leds<=6'b000000;
                    state<=ST_HALT;
                end
                default:state<=ST_HALT;
            endcase
        end
    end
    wire unused_initialized=initialized;
endmodule
