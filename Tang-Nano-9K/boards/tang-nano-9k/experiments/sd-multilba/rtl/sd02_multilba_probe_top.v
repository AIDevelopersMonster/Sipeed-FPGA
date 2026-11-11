// SD-02: autonomous FPGA -> SDHC multiple LBA probe with UART diagnostics.
// No PicoRV32, no firmware, no HDMI, no filesystem and no card writes.
// Top reports an independent CRC16 of all 512 bytes read back from block RAM.
// LBA order: 0, 1, 2048, 65541. Errors are shown as E=XX and summary FAIL.
// Physical S2 drives reset_n (pin 3). Active-low LEDs: LED1=PASS, all=FAIL.
// SPDX-License-Identifier: MIT
module sd02_multilba_probe_top #(
    parameter integer HALF_PERIOD=64,
    parameter integer STARTUP_CYCLES=27000,
    parameter integer UART_BAUD=115200
) (
    input  wire clk,
    input  wire reset_n,
    input  wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output wire sd_cs_n,
    output wire uart_tx,
    output wire [5:0] led_n
);
    reg sd_start;
    reg [31:0] sd_lba;
    wire sd_busy, sd_done, sd_initialized;
    wire [7:0] sd_error, peek_data;
    reg [8:0] peek_addr;
    lab05_sd_read_sector #(
        .HALF_PERIOD(HALF_PERIOD), .STARTUP_CYCLES(STARTUP_CYCLES)
    ) u_sd (
        .clk(clk), .reset_n(reset_n), .start(sd_start), .read_lba(sd_lba),
        .sd_miso(sd_miso), .sd_sck(sd_sck), .sd_mosi(sd_mosi),
        .sd_cs_n(sd_cs_n), .busy(sd_busy), .done(sd_done),
        .initialized(sd_initialized), .error_code(sd_error),
        .peek_addr(peek_addr), .peek_data(peek_data)
    );
    reg uart_start;
    reg [7:0] uart_data;
    wire uart_busy;
    uart_tx_8n1 #(.CLOCK_HZ(27000000),.BAUD(UART_BAUD)) u_uart (
        .clk(clk),.reset_n(reset_n),.start(uart_start),.data(uart_data),
        .tx(uart_tx),.busy(uart_busy)
    );

    reg [1:0] sequence;
    reg [8:0] index;
    reg [15:0] ram_crc;
    reg [7:0] head0,head1,tail0,tail1,error_latched;
    reg any_error, summary_mode;
    reg [5:0] char_pos;
    reg [5:0] state;
    reg [5:0] leds;
    assign led_n=leds;
    localparam [5:0]
        ST_BOOT=0, ST_WAIT_SD=1, ST_RAM_WAIT=2, ST_RAM_SAMPLE=3,
        ST_REPORT=4, ST_UART_BUSY=5, ST_UART_IDLE=6,
        ST_NEXT=7, ST_HALT=8;

    function [31:0] lba_for;
        input [1:0] which;
        begin
            case(which)
                2'd0: lba_for=32'd0;
                2'd1: lba_for=32'd1;
                2'd2: lba_for=32'd2048;
                default: lba_for=32'd65541;
            endcase
        end
    endfunction
    function [15:0] crc16_byte;
        input [15:0] prior;
        input [7:0] value;
        reg [15:0] current;
        integer k;
        begin
            current=prior;
            for(k=7;k>=0;k=k-1) begin
                if(current[15] ^ value[k])
                    current={current[14:0],1'b0} ^ 16'h1021;
                else
                    current={current[14:0],1'b0};
            end
            crc16_byte=current;
        end
    endfunction
    function [7:0] hex_char;
        input [3:0] nibble;
        begin
            hex_char = nibble<4'd10 ? (8'd48+{4'd0,nibble})
                                    : (8'd55+{4'd0,nibble});
        end
    endfunction

    // Fixed 47-byte record: SD02 LBA=XXXXXXXX CRC=XXXX H=XXXX T=XXXX E=XX\r\n
    // E=00 means that the card-provided data CRC matched. The RAM checksum
    // independently covers every byte after the block is read through peek_data.
    function [7:0] report_char;
        input [5:0] pos;
        input [31:0] lba;
        input [15:0] checksum;
        input [7:0] b0,b1,t0,t1,err;
        begin
            case(pos)
                6'd0: report_char = 8'h53;
                6'd1: report_char = 8'h44;
                6'd2: report_char = 8'h30;
                6'd3: report_char = 8'h32;
                6'd4: report_char = 8'h20;
                6'd5: report_char = 8'h4c;
                6'd6: report_char = 8'h42;
                6'd7: report_char = 8'h41;
                6'd8: report_char = 8'h3d;
                6'd9: report_char = hex_char(lba[31:28]);
                6'd10: report_char = hex_char(lba[27:24]);
                6'd11: report_char = hex_char(lba[23:20]);
                6'd12: report_char = hex_char(lba[19:16]);
                6'd13: report_char = hex_char(lba[15:12]);
                6'd14: report_char = hex_char(lba[11:8]);
                6'd15: report_char = hex_char(lba[7:4]);
                6'd16: report_char = hex_char(lba[3:0]);
                6'd17: report_char = 8'h20;
                6'd18: report_char = 8'h43;
                6'd19: report_char = 8'h52;
                6'd20: report_char = 8'h43;
                6'd21: report_char = 8'h3d;
                6'd22: report_char = hex_char(checksum[15:12]);
                6'd23: report_char = hex_char(checksum[11:8]);
                6'd24: report_char = hex_char(checksum[7:4]);
                6'd25: report_char = hex_char(checksum[3:0]);
                6'd26: report_char = 8'h20;
                6'd27: report_char = 8'h48;
                6'd28: report_char = 8'h3d;
                6'd29: report_char = hex_char(b0[7:4]);
                6'd30: report_char = hex_char(b0[3:0]);
                6'd31: report_char = hex_char(b1[7:4]);
                6'd32: report_char = hex_char(b1[3:0]);
                6'd33: report_char = 8'h20;
                6'd34: report_char = 8'h54;
                6'd35: report_char = 8'h3d;
                6'd36: report_char = hex_char(t0[7:4]);
                6'd37: report_char = hex_char(t0[3:0]);
                6'd38: report_char = hex_char(t1[7:4]);
                6'd39: report_char = hex_char(t1[3:0]);
                6'd40: report_char = 8'h20;
                6'd41: report_char = 8'h45;
                6'd42: report_char = 8'h3d;
                6'd43: report_char = hex_char(err[7:4]);
                6'd44: report_char = hex_char(err[3:0]);
                6'd45: report_char = 8'h0d;
                6'd46: report_char = 8'h0a;
                default: report_char = 8'h20;
            endcase
        end
    endfunction

    // Exactly "SD02 PASS\r\n" or "SD02 FAIL\r\n" (11 bytes).
    function [7:0] summary_char;
        input [5:0] pos;
        input failed;
        begin
            case(pos)
                6'd0:summary_char="S";
                6'd1:summary_char="D";
                6'd2:summary_char="0";
                6'd3:summary_char="2";
                6'd4:summary_char=" ";
                6'd5:summary_char=failed ? "F" : "P";
                6'd6:summary_char=failed ? "A" : "A";
                6'd7:summary_char=failed ? "I" : "S";
                6'd8:summary_char=failed ? "L" : "S";
                6'd9:summary_char=8'h0d;
                6'd10:summary_char=8'h0a;
                default:summary_char=8'h20;
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if(!reset_n) begin
            sd_start<=0;sd_lba<=0;
            uart_start<=0;uart_data<=0;
            sequence<=0;index<=0;peek_addr<=0;
            ram_crc<=0;head0<=0;head1<=0;tail0<=0;tail1<=0;
            error_latched<=0;any_error<=0;summary_mode<=0;char_pos<=0;
            leds<=6'b111111;state<=ST_BOOT;
        end else begin
            sd_start<=0;
            uart_start<=0;
            case(state)
                ST_BOOT: begin
                    sd_lba<=lba_for(2'd0);
                    sd_start<=1;
                    state<=ST_WAIT_SD;
                end
                ST_WAIT_SD: if(sd_done) begin
                    error_latched<=sd_error;
                    if(sd_error!=0) begin
                        any_error<=1;
                        ram_crc<=0;
                        head0<=0;head1<=0;tail0<=0;tail1<=0;
                        char_pos<=0;
                        state<=ST_REPORT;
                    end else begin
                        index<=0;
                        peek_addr<=0;
                        ram_crc<=0;
                        head0<=0;head1<=0;tail0<=0;tail1<=0;
                        state<=ST_RAM_WAIT;
                    end
                end
                ST_RAM_WAIT: state<=ST_RAM_SAMPLE;
                ST_RAM_SAMPLE: begin
                    ram_crc<=crc16_byte(ram_crc,peek_data);
                    if(index==9'd0) head0<=peek_data;
                    if(index==9'd1) head1<=peek_data;
                    if(index==9'd510) tail0<=peek_data;
                    if(index==9'd511) tail1<=peek_data;
                    if(index==9'd511) begin
                        char_pos<=0;
                        state<=ST_REPORT;
                    end else begin
                        index<=index+1'b1;
                        peek_addr<=index+1'b1;
                        state<=ST_RAM_WAIT;
                    end
                end
                ST_REPORT: if(!uart_busy) begin
                    uart_data<=summary_mode
                        ? summary_char(char_pos,any_error)
                        : report_char(char_pos,sd_lba,ram_crc,
                                      head0,head1,tail0,tail1,error_latched);
                    uart_start<=1;
                    state<=ST_UART_BUSY;
                end
                ST_UART_BUSY: if(uart_busy) state<=ST_UART_IDLE;
                ST_UART_IDLE: if(!uart_busy) begin
                    if(char_pos==(summary_mode ? 6'd10 : 6'd46)) begin
                        state<=summary_mode ? ST_HALT : ST_NEXT;
                    end else begin
                        char_pos<=char_pos+1'b1;
                        state<=ST_REPORT;
                    end
                end
                ST_NEXT: begin
                    if(sequence==2'd3 || (!sd_initialized && error_latched!=0)) begin
                        summary_mode<=1;
                        char_pos<=0;
                        state<=ST_REPORT;
                    end else begin
                        sequence<=sequence+1'b1;
                        sd_lba<=lba_for(sequence+1'b1);
                        sd_start<=1;
                        state<=ST_WAIT_SD;
                    end
                end
                ST_HALT: begin
                    leds<=any_error ? 6'b000000 : 6'b111110;
                    state<=ST_HALT;
                end
                default: state<=ST_HALT;
            endcase
        end
    end
    wire _unused_busy=sd_busy;
endmodule
