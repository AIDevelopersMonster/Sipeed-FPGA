// PiKoSoL LAB-04.2 v0.1.6: coherent low-rate LED mask transfer.
// Source: CPU/MMIO clk27. Destination: clk_pixel (25.2 MHz).
// A four-phase toggle handshake holds ALL SIX DATA BITS stable until the
// destination acknowledges capture. It may coalesce rapid source updates;
// the latest stable mask always propagates. Not a high-throughput FIFO.
// SPDX-License-Identifier: MIT
module lab04_led_mask_cdc (
    input wire clk_sys,
    input wire resetn_sys,
    input wire [5:0] mask_sys,
    input wire clk_pixel,
    input wire resetn_pixel,
    output reg [5:0] mask_pixel
);
    // Bundled-data mailbox: changes ONLY when the previous transfer is ACKed.
    reg [5:0] mask_hold_sys;
    reg req_sys;
    (* syn_keep = 1 *) reg ack_meta_sys;
    (* syn_keep = 1 *) reg ack_sync_sys;
    reg ack_pixel;
    (* syn_keep = 1 *) reg req_meta_pixel;
    (* syn_keep = 1 *) reg req_sync_pixel;

    always @(posedge clk_sys or negedge resetn_sys) begin
        if (!resetn_sys) begin
            mask_hold_sys <= 6'b0;
            req_sys <= 1'b0;
            ack_meta_sys <= 1'b0;
            ack_sync_sys <= 1'b0;
        end else begin
            ack_meta_sys <= ack_pixel;
            ack_sync_sys <= ack_meta_sys;
            if ((ack_sync_sys == req_sys) && (mask_hold_sys != mask_sys)) begin
                mask_hold_sys <= mask_sys;
                req_sys <= ~req_sys;
            end
        end
    end

    always @(posedge clk_pixel or negedge resetn_pixel) begin
        if (!resetn_pixel) begin
            req_meta_pixel <= 1'b0;
            req_sync_pixel <= 1'b0;
            ack_pixel <= 1'b0;
            mask_pixel <= 6'b0;
        end else begin
            req_meta_pixel <= req_sys;
            req_sync_pixel <= req_meta_pixel;
            if (req_sync_pixel != ack_pixel) begin
                // Source mailbox was held stable through the request sync.
                mask_pixel <= mask_hold_sys;
                ack_pixel <= req_sync_pixel;
            end
        end
    end
endmodule
