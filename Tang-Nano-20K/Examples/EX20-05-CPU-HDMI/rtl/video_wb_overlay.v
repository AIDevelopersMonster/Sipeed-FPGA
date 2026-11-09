// EX20-05 stage A: Wishbone B4 slave + atomic frame-boundary video update.
// CPU and pixel domains may run at different clocks. Reset must be asserted
// to both domains. Pixel inputs are active-video coordinates, not sync timing.
// NO TMDS, PLL, CPU, SDRAM or pin constraints are included in this module.
module video_wb_overlay #(
    parameter integer XW = 12,
    parameter integer YW = 12
) (
    input  wire        cpu_clk,
    input  wire        cpu_rst,
    input  wire        wb_cyc_i,
    input  wire        wb_stb_i,
    input  wire        wb_we_i,
    input  wire [7:0]  wb_adr_i, // byte address OFFSET relative to mapped base
    input  wire [31:0] wb_dat_i,
    input  wire [3:0]  wb_sel_i,
    output reg  [31:0] wb_dat_o,
    output reg         wb_ack_o,
    output reg         wb_err_o,
    input  wire        pix_clk,
    input  wire        pix_rst,
    input  wire        frame_start,
    input  wire        pix_de,
    input  wire [XW-1:0] pix_x,
    input  wire [YW-1:0] pix_y,
    output wire [7:0]  pix_r,
    output wire [7:0]  pix_g,
    output wire [7:0]  pix_b
);
    localparam [31:0] ID = 32'h56323031; // "V201"
    // 0x00 ID (RO); 0x04 BG RGB; 0x08 RECT XY; 0x0c RECT WH;
    // 0x10 RECT RGB; 0x14 STATUS (bit0=busy, bit1=ack-toggle);
    // 0x18 COMMIT (write 1); 0x1c VERSION (RO).
    reg [23:0] bg_stage, rect_stage;
    reg [31:0] xy_stage, wh_stage;
    reg commit_toggle;
    reg ack_sync1, ack_sync2;
    reg ack_toggle;
    wire busy = commit_toggle != ack_sync2;

    always @(posedge cpu_clk) begin
        if (cpu_rst) begin
            bg_stage <= 24'h102040;
            rect_stage <= 24'h00ff80;
            xy_stage <= {16'd90, 16'd120};
            wh_stage <= {16'd120, 16'd200};
            commit_toggle <= 1'b0;
            ack_sync1 <= 1'b0;
            ack_sync2 <= 1'b0;
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
            wb_dat_o <= 32'b0;
        end else begin
            ack_sync1 <= ack_toggle;
            ack_sync2 <= ack_sync1;
            wb_ack_o <= 1'b0;
            wb_err_o <= 1'b0;
            if (wb_cyc_i && wb_stb_i && !wb_ack_o && !wb_err_o) begin
                if (wb_we_i) begin
                    if (wb_sel_i != 4'hf || (busy &&
                        (wb_adr_i == 8'h04 || wb_adr_i == 8'h08 ||
                         wb_adr_i == 8'h0c || wb_adr_i == 8'h10 ||
                         wb_adr_i == 8'h18))) begin
                        wb_err_o <= 1'b1;
                    end else begin
                        case (wb_adr_i)
                            8'h04: bg_stage <= wb_dat_i[23:0];
                            8'h08: xy_stage <= wb_dat_i;
                            8'h0c: wh_stage <= wb_dat_i;
                            8'h10: rect_stage <= wb_dat_i[23:0];
                            8'h18: if (wb_dat_i[0]) commit_toggle <= ~commit_toggle;
                            default: wb_err_o <= 1'b1;
                        endcase
                        if (wb_adr_i == 8'h04 || wb_adr_i == 8'h08 ||
                            wb_adr_i == 8'h0c || wb_adr_i == 8'h10 ||
                            wb_adr_i == 8'h18) wb_ack_o <= 1'b1;
                    end
                end else begin
                    case (wb_adr_i)
                        8'h00: wb_dat_o <= ID;
                        8'h04: wb_dat_o <= {8'b0, bg_stage};
                        8'h08: wb_dat_o <= xy_stage;
                        8'h0c: wb_dat_o <= wh_stage;
                        8'h10: wb_dat_o <= {8'b0, rect_stage};
                        8'h14: wb_dat_o <= {30'b0, ack_sync2, busy};
                        8'h18: wb_dat_o <= {31'b0, commit_toggle};
                        8'h1c: wb_dat_o <= 32'h00010000;
                        default: wb_dat_o <= 32'b0;
                    endcase
                    if (wb_adr_i <= 8'h1c && wb_adr_i[1:0] == 0)
                        wb_ack_o <= 1'b1;
                    else wb_err_o <= 1'b1;
                end
            end
        end
    end

    // Two-flop control synchronizer. Stage data is immutable while busy=1
    // and is sampled only at frame_start after the toggle crosses domains.
    (* async_reg = "true" *) reg commit_sync1, commit_sync2;
    reg [23:0] bg_live, rect_live;
    reg [31:0] xy_live, wh_live;
    always @(posedge pix_clk) begin
        if (pix_rst) begin
            commit_sync1 <= 1'b0;
            commit_sync2 <= 1'b0;
            ack_toggle <= 1'b0;
            bg_live <= 24'h102040;
            rect_live <= 24'h00ff80;
            xy_live <= {16'd90, 16'd120};
            wh_live <= {16'd120, 16'd200};
        end else begin
            commit_sync1 <= commit_toggle;
            commit_sync2 <= commit_sync1;
            if (frame_start && commit_sync2 != ack_toggle) begin
                bg_live <= bg_stage;
                rect_live <= rect_stage;
                xy_live <= xy_stage;
                wh_live <= wh_stage;
                ack_toggle <= commit_sync2;
            end
        end
    end

    wire [15:0] rx = xy_live[15:0], ry = xy_live[31:16];
    wire [15:0] rw = wh_live[15:0], rh = wh_live[31:16];
    wire rect_hit = (rw != 0 && rh != 0) &&
                  ({4'b0,pix_x} >= rx) && ({4'b0,pix_y} >= ry) &&
                  ({4'b0,pix_x} - rx < rw) && ({4'b0,pix_y} - ry < rh);
    wire [23:0] rgb = pix_de ? (rect_hit ? rect_live : bg_live) : 24'h000000;
    assign {pix_r,pix_g,pix_b} = rgb;
endmodule
