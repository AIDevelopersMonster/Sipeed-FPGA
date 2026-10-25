// SD-06B -- CMD24 SPI byte-engine, standalone mock-test target only.
// NO TOP/CONSTRAINTS/FS. Do not attach to physical media.
// Caller must already have initialized SDHC SPI mode separately.
// The caller is responsible for card identity, backup, explicit LBA approval,
// preimage hash, power-loss risks and final independent CMD17 verification.
// 27MHz single clock, SPI mode 0 via proven lab05_spi_byte.
// SPDX-License-Identifier: MIT
module sd06_cmd24_engine #(
    parameter integer HALF_PERIOD = 64,
    parameter integer MAX_R1_POLLS = 32,
    parameter integer MAX_RESP_POLLS = 8,
    parameter integer MAX_BUSY_BYTES = 8192
)(
    input wire clk,
    input wire reset_n,
    input wire load_valid,
    input wire [8:0] load_addr,
    input wire [7:0] load_byte,
    input wire start,
    input wire card_ready,
    input wire authorized,
    input wire [31:0] request_lba,
    input wire [31:0] approved_lba,
    input wire sd_miso,
    output wire sd_sck,
    output wire sd_mosi,
    output reg sd_cs_n,
    output reg busy,
    output reg done,
    output reg [7:0] error_code,
    output wire payload_ready
);
    // Errors: F1 preflight/authorization; F2 CMD24 R1; F3 R1 timeout;
    // F4 data response rejected (CRC or write); F5 data response timeout;
    // F6 post-write busy timeout. Successful=00.
    localparam [2:0] S_IDLE=0, S_SEND=1, S_WAIT_BUSY=2,
                     S_WAIT_DONE=3, S_FINISH=4;
    localparam [3:0] P_GAP=0, P_CMD=1, P_R1=2, P_TOKEN_GAP=3,
                     P_TOKEN=4, P_DATA=5, P_CRC_HI=6, P_CRC_LO=7,
                     P_RESP=8, P_BUSY=9, P_RELEASE=10;
    reg [2:0] state;
    reg [3:0] phase;
    reg [7:0] payload [0:511] /* synthesis syn_ramstyle = "block_ram" */;
    reg [9:0] load_count;
    reg [31:0] lba_hold;
    reg [2:0] cmd_pos;
    reg [8:0] data_pos;
    reg [15:0] data_crc;
    reg [7:0] r1_count, response_count;
    reg [15:0] busy_count;
    reg spi_start;
    reg [7:0] spi_tx;
    wire spi_busy,spi_done;
    wire [7:0] spi_rx;

    assign payload_ready = (load_count == 10'd512);

    lab05_spi_byte #(.HALF_PERIOD(HALF_PERIOD)) u_spi (
        .clk(clk), .reset_n(reset_n), .start(spi_start),
        .tx_data(spi_tx), .miso(sd_miso), .sck(sd_sck),
        .mosi(sd_mosi), .busy(spi_busy), .done(spi_done),
        .rx_data(spi_rx)
    );

    function [15:0] crc16_next;
        input [15:0] prev;
        input [7:0] val;
        reg [15:0] crc;
        integer k;
        begin
            crc = prev ^ {val,8'h00};
            for (k=0;k<8;k=k+1)
                crc = crc[15] ? {crc[14:0],1'b0} ^ 16'h1021
                              : {crc[14:0],1'b0};
            crc16_next = crc;
        end
    endfunction

    function [7:0] command_byte;
        input [2:0] index;
        input [31:0] address;
        begin
            case (index)
                0: command_byte=8'h58; // CMD24 = 0x40+24
                1: command_byte=address[31:24];
                2: command_byte=address[23:16];
                3: command_byte=address[15:8];
                4: command_byte=address[7:0];
                default: command_byte=8'h01; // CRC off after SDHC init
            endcase
        end
    endfunction

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            state<=S_IDLE;phase<=P_GAP;
            load_count<=0;
            lba_hold<=0;
            cmd_pos<=0;data_pos<=0;data_crc<=0;
            r1_count<=0;response_count<=0;busy_count<=0;
            spi_start<=0;spi_tx<=8'hff;sd_cs_n<=1;
            busy<=0;done<=0;error_code<=0;
        end else begin
            spi_start<=0;
            done<=0;
            case (state)
                S_IDLE: begin
                    if (load_valid) begin
                        if (load_addr == load_count[8:0] && load_count < 512) begin
                            payload[load_addr]<=load_byte;
                            load_count<=load_count+1'b1;
                        end else begin
                            // Fail closed: sequence must restart at byte zero.
                            load_count<=0;
                        end
                    end
                    if (start) begin
                        if (!card_ready || !authorized || !payload_ready ||
                            request_lba==0 || request_lba!=approved_lba ||
                            load_valid) begin
                            error_code<=8'hf1;done<=1;
                        end else begin
                            busy<=1;error_code<=0;
                            lba_hold<=request_lba;
                            sd_cs_n<=0;
                            cmd_pos<=0;data_pos<=0;
                            data_crc<=0;response_count<=0;
                            busy_count<=0;r1_count<=0;
                            phase<=P_GAP;state<=S_SEND;
                        end
                    end
                end
                S_SEND: if (!spi_busy) begin
                    case (phase)
                        P_CMD: spi_tx<=command_byte(cmd_pos,lba_hold);
                        P_TOKEN: spi_tx<=8'hfe;
                        P_DATA: spi_tx<=payload[data_pos];
                        P_CRC_HI: spi_tx<=data_crc[15:8];
                        P_CRC_LO: spi_tx<=data_crc[7:0];
                        default: spi_tx<=8'hff;
                    endcase
                    spi_start<=1;
                    state<=S_WAIT_BUSY;
                end
                S_WAIT_BUSY: if (spi_busy) state<=S_WAIT_DONE;
                S_WAIT_DONE: if (spi_done) begin
                    state<=S_SEND;
                    case (phase)
                        P_GAP: begin cmd_pos<=0;phase<=P_CMD;end
                        P_CMD: if (cmd_pos==5) begin
                                   phase<=P_R1;r1_count<=0;
                               end else cmd_pos<=cmd_pos+1'b1;
                        P_R1: begin
                            if (spi_rx[7]) begin
                                if (r1_count==MAX_R1_POLLS-1) begin
                                    error_code<=8'hf3;phase<=P_RELEASE;
                                    sd_cs_n<=1;
                                end else r1_count<=r1_count+1'b1;
                            end else if (spi_rx != 8'h00) begin
                                error_code<=8'hf2;phase<=P_RELEASE;
                                sd_cs_n<=1;
                            end else phase<=P_TOKEN_GAP;
                        end
                        P_TOKEN_GAP:phase<=P_TOKEN;
                        P_TOKEN:begin data_crc<=0;data_pos<=0;phase<=P_DATA;end
                        P_DATA:begin
                            data_crc<=crc16_next(data_crc,payload[data_pos]);
                            if (data_pos==511) phase<=P_CRC_HI;
                            else data_pos<=data_pos+1'b1;
                        end
                        P_CRC_HI:phase<=P_CRC_LO;
                        P_CRC_LO:begin phase<=P_RESP;response_count<=0;end
                        P_RESP:begin
                            if (spi_rx==8'hff) begin
                                if (response_count==MAX_RESP_POLLS-1) begin
                                    error_code<=8'hf5;phase<=P_RELEASE;
                                    sd_cs_n<=1;
                                end else response_count<=response_count+1'b1;
                            end else if ((spi_rx & 8'h1f) == 8'h05) begin
                                phase<=P_BUSY;busy_count<=0;
                            end else begin
                                error_code<=8'hf4;phase<=P_RELEASE;
                                sd_cs_n<=1;
                            end
                        end
                        P_BUSY:begin
                            if (spi_rx==8'hff) begin
                                phase<=P_RELEASE;sd_cs_n<=1;
                            end else if (busy_count==MAX_BUSY_BYTES-1) begin
                                error_code<=8'hf6;phase<=P_RELEASE;
                                sd_cs_n<=1;
                            end else busy_count<=busy_count+1'b1;
                        end
                        P_RELEASE:state<=S_FINISH;
                        default:begin error_code<=8'hf4;sd_cs_n<=1;
                                      phase<=P_RELEASE;end
                    endcase
                end
                S_FINISH:begin
                    busy<=0;done<=1;load_count<=0;state<=S_IDLE;
                end
                default:begin sd_cs_n<=1;busy<=0;state<=S_IDLE;end
            endcase
        end
    end
endmodule
