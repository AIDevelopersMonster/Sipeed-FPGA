// PiKoSoL LAB-05.1 independent on-board microSD diagnostic bitstream.
// SDHC only; read-only, CMD17 LBA0 + CRC16, no writes, no LAB-04 changes.
// Auto-runs after reset and reports to FTDI/BL702 UART at 115200 8N1.
// LEDs: LED1 ON = PASS, all six ON = error; UART tells exact error code.
// NOT a PicoRV32/HDMI build: separate hardware gate before SoC integration.
// SPDX-License-Identifier: MIT
module lab05_sd_probe_top (
    input wire clk,
    input wire reset_n,
    input wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output wire sd_cs_n,
    output wire uart_tx,
    output wire [5:0] led_n
);
    reg sd_start;
    wire sd_busy, sd_done, sd_initialized;
    wire [7:0] sd_error;
    reg [8:0] peek_addr;
    wire [7:0] peek_data;
    lab05_sd_init_read0 #(
        .HALF_PERIOD(64),
        .STARTUP_CYCLES(27000)
    ) u_sd (
        .clk(clk), .reset_n(reset_n), .start(sd_start),
        .sd_miso(sd_miso), .sd_sck(sd_sck), .sd_mosi(sd_mosi),
        .sd_cs_n(sd_cs_n), .busy(sd_busy), .done(sd_done),
        .initialized(sd_initialized), .error_code(sd_error),
        .peek_addr(peek_addr), .peek_data(peek_data)
    );
    reg uart_start;
    reg [7:0] uart_data;
    wire uart_busy;
    uart_tx_8n1 #(.CLOCK_HZ(27000000), .BAUD(115200)) u_uart (
        .clk(clk), .reset_n(reset_n), .start(uart_start),
        .data(uart_data), .tx(uart_tx), .busy(uart_busy)
    );

    reg [7:0] signature_0, signature_1, error_latched;
    reg ok;
    reg [4:0] msg_pos;
    reg [5:0] leds;
    assign led_n=leds;
    localparam [3:0]
        ST_BOOT=0, ST_WAIT_SD=1,
        ST_PEEK0_WAIT=2, ST_PEEK0_CAPTURE=3,
        ST_PEEK1_WAIT=4, ST_PEEK1_CAPTURE=5,
        ST_EMIT=6, ST_UART_BUSY=7, ST_UART_FINISH=8, ST_HALT=9;
    reg [3:0] state;

    function [7:0] hex_char;
        input [3:0] nibble;
        begin hex_char = (nibble < 4'd10) ? (8'd48 + {4'd0,nibble})
                            : (8'd55 + {4'd0,nibble}); end
    endfunction
    function [7:0] report_char;
        input good;
        input [4:0] idx;
        input [7:0] sig0, sig1, err;
        begin
            report_char=8'h20;
            if (good) begin
                // "SD PASS SIG=xxxx\r\n" -- 18 bytes
                case (idx)
                    0:report_char="S"; 1:report_char="D"; 2:report_char=" ";
                    3:report_char="P"; 4:report_char="A"; 5:report_char="S";
                    6:report_char="S"; 7:report_char=" "; 8:report_char="S";
                    9:report_char="I"; 10:report_char="G"; 11:report_char="=";
                    12:report_char=hex_char(sig0[7:4]);
                    13:report_char=hex_char(sig0[3:0]);
                    14:report_char=hex_char(sig1[7:4]);
                    15:report_char=hex_char(sig1[3:0]);
                    16:report_char=8'h0d; 17:report_char=8'h0a;
                    default:report_char=8'h20;
                endcase
            end else begin
                // "SD ERR=xx\r\n" -- 11 bytes
                case (idx)
                    0:report_char="S"; 1:report_char="D"; 2:report_char=" ";
                    3:report_char="E"; 4:report_char="R"; 5:report_char="R";
                    6:report_char="=";
                    7:report_char=hex_char(err[7:4]);
                    8:report_char=hex_char(err[3:0]);
                    9:report_char=8'h0d; 10:report_char=8'h0a;
                    default:report_char=8'h20;
                endcase
            end
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            sd_start<=0;
            uart_start<=0;
            uart_data<=0;
            peek_addr<=0;
            signature_0<=0;
            signature_1<=0;
            error_latched<=0;
            ok<=0;
            msg_pos<=0;
            leds<=6'b111111;
            state<=ST_BOOT;
        end else begin
            sd_start<=0;
            uart_start<=0;
            case (state)
                ST_BOOT: begin sd_start<=1; state<=ST_WAIT_SD; end
                ST_WAIT_SD: if (sd_done) begin
                    ok <= sd_initialized && (sd_error==8'h00);
                    error_latched<=sd_error;
                    peek_addr<=9'd510;
                    state<=ST_PEEK0_WAIT;
                end
                // Synchronous peek RAM: wait then sample registered output.
                ST_PEEK0_WAIT: state<=ST_PEEK0_CAPTURE;
                ST_PEEK0_CAPTURE: begin
                    signature_0<=peek_data;
                    peek_addr<=9'd511;
                    state<=ST_PEEK1_WAIT;
                end
                ST_PEEK1_WAIT: state<=ST_PEEK1_CAPTURE;
                ST_PEEK1_CAPTURE: begin
                    signature_1<=peek_data;
                    leds <= ok ? 6'b111110 : 6'b000000;
                    msg_pos<=0;
                    state<=ST_EMIT;
                end
                ST_EMIT: begin
                    if (msg_pos==(ok ? 5'd18 : 5'd11)) begin
                        state<=ST_HALT;
                    end else if (!uart_busy) begin
                        uart_data<=report_char(ok,msg_pos,signature_0,signature_1,error_latched);
                        uart_start<=1;
                        state<=ST_UART_BUSY;
                    end
                end
                ST_UART_BUSY: if (uart_busy) state<=ST_UART_FINISH;
                ST_UART_FINISH: if (!uart_busy) begin
                    msg_pos<=msg_pos+1'b1;
                    state<=ST_EMIT;
                end
                ST_HALT: state<=ST_HALT;
                default: state<=ST_HALT;
            endcase
        end
    end
    wire _unused=sd_busy;
endmodule
