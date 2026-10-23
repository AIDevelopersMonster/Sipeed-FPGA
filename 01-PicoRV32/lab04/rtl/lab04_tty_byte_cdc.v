// PiKoSoL v0.1.8b. Lossless one-byte bundled-data CDC.
// Sys UART tap -> pixel-domain console parser. No async bus sampling:
// source data is stable from request until synchronized acknowledgment.
// SPDX-License-Identifier: MIT
module lab04_tty_byte_cdc (
    input wire clk_sys, input wire resetn_sys,
    input wire char_valid, output wire char_ready, input wire [7:0] char_data,
    input wire clk_pixel, input wire resetn_pixel,
    input wire pixel_accept,
    output reg event_valid, output reg [7:0] event_byte
);
    reg [7:0] char_hold_sys;
    reg req_sys;
    (* syn_keep = 1 *) reg ack_meta_sys;
    (* syn_keep = 1 *) reg ack_sync_sys;
    (* syn_keep = 1 *) reg req_meta_pixel;
    (* syn_keep = 1 *) reg req_sync_pixel;
    reg ack_pixel;
    assign char_ready = (req_sys == ack_sync_sys);
    always @(posedge clk_sys or negedge resetn_sys) begin
        if (!resetn_sys) begin
            char_hold_sys <= 8'h00;
            req_sys <= 1'b0;
            ack_meta_sys <= 1'b0;
            ack_sync_sys <= 1'b0;
        end else begin
            ack_meta_sys <= ack_pixel;
            ack_sync_sys <= ack_meta_sys;
            if (char_valid && char_ready) begin
                char_hold_sys <= char_data;
                req_sys <= ~req_sys;
            end
        end
    end
    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            req_meta_pixel <= 1'b0;
            req_sync_pixel <= 1'b0;
            ack_pixel <= 1'b0;
            event_valid <= 1'b0;
            event_byte <= 8'h00;
        end else begin
            req_meta_pixel <= req_sys;
            req_sync_pixel <= req_meta_pixel;
            event_valid <= 1'b0;
            if ((req_sync_pixel != ack_pixel) && pixel_accept) begin
                event_byte <= char_hold_sys;
                event_valid <= 1'b1;
                ack_pixel <= req_sync_pixel;
            end
        end
    end
endmodule
