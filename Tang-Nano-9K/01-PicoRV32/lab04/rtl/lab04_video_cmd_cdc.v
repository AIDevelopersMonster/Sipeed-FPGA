// PiKoSoL LAB-04.3. Lossless, CPU-backpressured MMIO command mailbox.
// CLK_SYS=27 MHz -> CLK_PIXEL=25.2 MHz. 28-bit bundled data is held until ACK.
// Each accepted 32-bit MMIO store becomes EXACTLY ONE pixel-side event.
// A stalled CPU cannot overwrite an in-flight packet. No free-running async bus.
// For Gowin STA: constrain request/ack first stages and all packet data bits;
// verify real endpoint matches (do not globally false-path the clocks).
// SPDX-License-Identifier: MIT
module lab04_video_cmd_cdc (
    input wire clk_sys,
    input wire resetn_sys,
    input wire wr_valid,
    output wire wr_ready,
    input wire [3:0] wr_index,
    input wire [23:0] wr_value,
    input wire clk_pixel,
    input wire resetn_pixel,
    output reg event_valid,
    output reg [3:0] event_index,
    output reg [23:0] event_value
);
    reg [27:0] packet_hold_sys;
    reg req_sys;
    (* syn_keep = 1 *) reg ack_meta_sys;
    (* syn_keep = 1 *) reg ack_sync_sys;
    (* syn_keep = 1 *) reg req_meta_pixel;
    (* syn_keep = 1 *) reg req_sync_pixel;
    reg ack_pixel;
    assign wr_ready = (req_sys == ack_sync_sys);
    always @(posedge clk_sys or negedge resetn_sys) begin
        if (!resetn_sys) begin
            packet_hold_sys <= 28'd0;
            req_sys <= 1'b0;
            ack_meta_sys <= 1'b0;
            ack_sync_sys <= 1'b0;
        end else begin
            ack_meta_sys <= ack_pixel;
            ack_sync_sys <= ack_meta_sys;
            if (wr_valid && wr_ready) begin
                packet_hold_sys <= {wr_index, wr_value};
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
            event_index <= 4'd0;
            event_value <= 24'd0;
        end else begin
            req_meta_pixel <= req_sys;
            req_sync_pixel <= req_meta_pixel;
            event_valid <= 1'b0;
            if (req_sync_pixel != ack_pixel) begin
                event_index <= packet_hold_sys[27:24];
                event_value <= packet_hold_sys[23:0];
                event_valid <= 1'b1;
                ack_pixel <= req_sync_pixel;
            end
        end
    end
endmodule
