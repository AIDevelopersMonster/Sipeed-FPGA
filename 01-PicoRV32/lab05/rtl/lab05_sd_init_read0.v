// LAB-05.1 SDHC SPI bring-up: initialize card and read LBA0.
// One 27 MHz clock domain. SD SCK is an output waveform, not a fabric clock.
// SDHC/SDXC block addressing only; fail closed for non-SDHC.
// Produces full 512-byte synchronous sector RAM plus CRC16 verification.
// Experimental source, NOT hardware qualified.
// SPDX-License-Identifier: MIT
module lab05_sd_init_read0 (
    input wire clk,
    input wire reset_n,
    input wire start,
    input wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output reg sd_cs_n,
    output reg busy,
    output reg done,
    output reg initialized,
    output reg [7:0] error_code,
    input wire [8:0] peek_addr,
    output reg [7:0] peek_data
);
    // Error: E1=CMD0; E2=CMD8; E3=CMD55; E4=ACMD41 timeout;
    // E5=CMD58; E6=CMD17; E7=non-SDHC; E8=R1 timeout;
    // E9=data token timeout/error; EA=data CRC16; EB=CMD8 echo.
    localparam [2:0] S_IDLE=0, S_STARTUP=1, S_SEND=2,
                     S_WAIT=3, S_DONE=4;
    localparam [3:0] PH_POWER=0, PH_GAP=1, PH_CMD=2, PH_R1=3,
                     PH_EXTRA=4, PH_TOKEN=5, PH_DATA=6,
                     PH_CRC_HI=7, PH_CRC_LO=8, PH_RELEASE=9;
    reg [2:0] state;
    reg [3:0] phase;
    reg spi_start;
    reg [7:0] spi_tx;
    wire spi_busy,spi_done;
    wire [7:0] spi_rx;
    lab05_spi_byte #(.HALF_PERIOD(64)) u_spi (
        .clk(clk),.reset_n(reset_n),.start(spi_start),.tx_data(spi_tx),
        .miso(sd_miso),.sck(sd_sck),.mosi(sd_mosi),
        .busy(spi_busy),.done(spi_done),.rx_data(spi_rx)
    );

    reg [15:0] startup_count;
    reg [3:0] power_count;
    reg [2:0] cmd_pos, extra_pos;
    reg [5:0] command;
    reg [5:0] r1_poll;
    reg [8:0] acmd_attempts;
    reg [12:0] token_polls;
    reg [8:0] data_pos;
    reg [7:0] r7_vhs, ocr_high, crc_hi;
    reg [15:0] crc16;

    reg [7:0] sector [0:511] /* synthesis syn_ramstyle = "block_ram" */;
    always @(posedge clk) peek_data <= sector[peek_addr];

    function [15:0] crc16_next;
        input [15:0] previous;
        input [7:0] value;
        integer b;
        reg [15:0] c;
        begin
            c = previous;
            for (b=7;b>=0;b=b-1)
                if (c[15] ^ value[b])
                    c = {c[14:0],1'b0} ^ 16'h1021;
                else
                    c = {c[14:0],1'b0};
            crc16_next=c;
        end
    endfunction

    function [7:0] command_byte;
        input [5:0] cmd;
        input [2:0] pos;
        begin
            case (pos)
              3'd0: command_byte=8'h40 | {2'b00,cmd};
              3'd1: command_byte=(cmd==6'd41) ? 8'h40 : 8'h00;
              3'd2: command_byte=8'h00;
              3'd3: command_byte=(cmd==6'd8) ? 8'h01 : 8'h00;
              3'd4: command_byte=(cmd==6'd8) ? 8'haa : 8'h00;
              default: command_byte=(cmd==6'd0) ? 8'h95 :
                                    (cmd==6'd8) ? 8'h87 : 8'h01;
            endcase
        end
    endfunction

    // The only state allowed to send a byte is S_SEND. Each command's
    // response, payload, token and CRC is consumed exactly once on spi_done.
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state <= S_IDLE;
            phase <= PH_POWER;
            spi_start <= 0;
            spi_tx <= 8'hff;
            sd_cs_n <= 1;
            busy <= 0;
            done <= 0;
            initialized <= 0;
            error_code <= 0;
            startup_count <= 0;
            power_count <= 0;
            cmd_pos <= 0;
            extra_pos <= 0;
            command <= 0;
            r1_poll <= 0;
            acmd_attempts <= 0;
            token_polls <= 0;
            data_pos <= 0;
            r7_vhs <= 0;
            ocr_high <= 0;
            crc_hi <= 0;
            crc16 <= 0;
        end else begin
            spi_start <= 0;
            done <= 0;
            case (state)
                S_IDLE: if (start) begin
                    busy <= 1;
                    initialized <= 0;
                    error_code <= 0;
                    sd_cs_n <= 1;
                    startup_count <= 0;
                    power_count <= 0;
                    command <= 0; // CMD0
                    acmd_attempts <= 0;
                    phase <= PH_POWER;
                    state <= S_STARTUP;
                end
                S_STARTUP: begin
                    // 1 ms of stable powered card supply after FPGA start.
                    if (startup_count == 16'd26999)
                        state <= S_SEND;
                    else
                        startup_count <= startup_count+1'b1;
                end
                S_SEND: if (!spi_busy) begin
                    case (phase)
                        PH_POWER,PH_GAP,PH_R1,PH_EXTRA,
                        PH_TOKEN,PH_DATA,PH_CRC_HI,PH_CRC_LO,
                        PH_RELEASE: spi_tx <= 8'hff;
                        PH_CMD: spi_tx <= command_byte(command,cmd_pos);
                        default: spi_tx <= 8'hff;
                    endcase
                    spi_start <= 1;
                    state <= S_WAIT;
                end
                S_WAIT: if (spi_done) begin
                    case (phase)
                        PH_POWER: begin
                            if (power_count==4'd9) begin
                                sd_cs_n<=0;
                                phase<=PH_GAP;
                            end else
                                power_count<=power_count+1'b1;
                            state<=S_SEND;
                        end
                        PH_GAP: begin
                            cmd_pos<=0;
                            phase<=PH_CMD;
                            state<=S_SEND;
                        end
                        PH_CMD: begin
                            if (cmd_pos==3'd5) begin
                                r1_poll<=0;
                                phase<=PH_R1;
                            end else
                                cmd_pos<=cmd_pos+1'b1;
                            state<=S_SEND;
                        end
                        PH_R1: begin
                            if (spi_rx[7]) begin
                                if (r1_poll==6'd31) begin
                                    error_code<=8'he8;
                                    phase<=PH_RELEASE;
                                end else
                                    r1_poll<=r1_poll+1'b1;
                            end else begin
                                case (command)
                                    6'd0: begin
                                        if (spi_rx==8'h01) begin
                                            command<=6'd8;
                                            phase<=PH_GAP;
                                        end else begin
                                            error_code<=8'he1;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    6'd8: begin
                                        if (spi_rx==8'h01) begin
                                            extra_pos<=0;
                                            phase<=PH_EXTRA;
                                        end else begin
                                            error_code<=8'he2;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    6'd55: begin
                                        if (spi_rx==8'h01 || spi_rx==8'h00) begin
                                            command<=6'd41;
                                            phase<=PH_GAP;
                                        end else begin
                                            error_code<=8'he3;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    6'd41: begin
                                        if (spi_rx==8'h00) begin
                                            command<=6'd58;
                                            phase<=PH_GAP;
                                        end else if (spi_rx==8'h01 && acmd_attempts!=9'd255) begin
                                            acmd_attempts<=acmd_attempts+1'b1;
                                            command<=6'd55;
                                            phase<=PH_GAP;
                                        end else begin
                                            error_code<=8'he4;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    6'd58: begin
                                        if (spi_rx==8'h00) begin
                                            extra_pos<=0;
                                            phase<=PH_EXTRA;
                                        end else begin
                                            error_code<=8'he5;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    6'd17: begin
                                        if (spi_rx==8'h00) begin
                                            token_polls<=0;
                                            phase<=PH_TOKEN;
                                        end else begin
                                            error_code<=8'he6;
                                            phase<=PH_RELEASE;
                                        end
                                    end
                                    default: begin
                                        error_code<=8'hff;
                                        phase<=PH_RELEASE;
                                    end
                                endcase
                            end
                            state<=S_SEND;
                        end
                        PH_EXTRA: begin
                            if (command==6'd8) begin
                                if (extra_pos==3'd2)
                                    r7_vhs<=spi_rx;
                                if (extra_pos==3'd3) begin
                                    if (r7_vhs!=8'h01 || spi_rx!=8'haa) begin
                                        error_code<=8'heb;
                                        phase<=PH_RELEASE;
                                    end else begin
                                        command<=6'd55;
                                        phase<=PH_GAP;
                                    end
                                end
                            end
                            if (command==6'd58) begin
                                if (extra_pos==3'd0)
                                    ocr_high<=spi_rx;
                                if (extra_pos==3'd3) begin
                                    if (!ocr_high[6]) begin
                                        error_code<=8'he7; // SDSC unsupported
                                        phase<=PH_RELEASE;
                                    end else begin
                                        initialized<=1;
                                        command<=6'd17;
                                        phase<=PH_GAP;
                                    end
                                end
                            end
                            if (extra_pos!=3'd3 && phase==PH_EXTRA)
                                extra_pos<=extra_pos+1'b1;
                            state<=S_SEND;
                        end
                        PH_TOKEN: begin
                            if (spi_rx==8'hfe) begin
                                data_pos<=0;
                                crc16<=0;
                                phase<=PH_DATA;
                            end else if (spi_rx!=8'hff || token_polls==13'd4095) begin
                                error_code<=8'he9;
                                phase<=PH_RELEASE;
                            end else
                                token_polls<=token_polls+1'b1;
                            state<=S_SEND;
                        end
                        PH_DATA: begin
                            sector[data_pos]<=spi_rx;
                            crc16<=crc16_next(crc16,spi_rx);
                            if (data_pos==9'd511) begin
                                phase<=PH_CRC_HI;
                            end else
                                data_pos<=data_pos+1'b1;
                            state<=S_SEND;
                        end
                        PH_CRC_HI: begin
                            crc_hi<=spi_rx;
                            phase<=PH_CRC_LO;
                            state<=S_SEND;
                        end
                        PH_CRC_LO: begin
                            if ({crc_hi,spi_rx}!=crc16)
                                error_code<=8'hea;
                            phase<=PH_RELEASE;
                            state<=S_SEND;
                        end
                        PH_RELEASE: begin
                            sd_cs_n<=1'b1;
                            state<=S_DONE;
                        end
                        default: state<=S_DONE;
                    endcase
                end
                S_DONE: begin
                    busy<=0;
                    done<=1;
                    state<=S_IDLE;
                end
                default: state<=S_IDLE;
            endcase
        end
    end
endmodule
