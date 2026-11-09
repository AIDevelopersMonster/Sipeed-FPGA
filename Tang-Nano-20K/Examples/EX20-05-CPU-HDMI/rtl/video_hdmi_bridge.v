// EX20-05 stage B: combined LiteX Wishbone register slave and HDMI pixel source.
// Tang Nano 20K, 27 MHz reference; no external framebuffer.
// Vendor PLL and DVI_TX_Top are acquired from pinned Sipeed sources.
module video_hdmi_bridge (
    input wire clk27,
    input wire cpu_clk,
    input wire cpu_rst,
    input wire wb_cyc_i,
    input wire wb_stb_i,
    input wire wb_we_i,
    input wire [7:0] wb_adr_i,
    input wire [31:0] wb_dat_i,
    input wire [3:0] wb_sel_i,
    output wire [31:0] wb_dat_o,
    output wire wb_ack_o,
    output wire wb_err_o,
    output wire tmds_clk_p,
    output wire tmds_clk_n,
    output wire [2:0] tmds_data_p,
    output wire [2:0] tmds_data_n,
    output wire video_locked
);
    wire serial_clk, pix_clk, pll_lock;
    TMDS_rPLL pll (.clkin(clk27), .clkout(serial_clk), .lock(pll_lock));
    wire pix_reset_n = pll_lock && !cpu_rst;

    // Async assertion, synchronous release in pixel domain.
    // CLKDIV and vendor DVI reset connections remain unchanged.
    (* async_reg = "true" *) reg [1:0] pix_rst_release = 2'b00;

    always @(posedge pix_clk or negedge pix_reset_n) begin
        if (!pix_reset_n)
            pix_rst_release <= 2'b00;
        else
            pix_rst_release <= {pix_rst_release[0], 1'b1};
    end

    wire pix_logic_reset_n = pix_rst_release[1];
    CLKDIV clkdiv(
        .RESETN(pix_reset_n),
        .HCLKIN(serial_clk),
        .CLKOUT(pix_clk),
        .CALIB(1'b1)
    );
    defparam clkdiv.DIV_MODE = "5";
    defparam clkdiv.GSREN = "false";
    assign video_locked = pll_lock;

    // 720p nominal 60 Hz: 1650x750 @74.25 MHz.
    // HS positive 40 px / back porch 220 / active 1280 / front 110.
    // VS positive 5 lines / back porch 20 / active 720 / front 5.
    reg [11:0] hcount=0, vcount=0;
    always @(posedge pix_clk or negedge pix_logic_reset_n) begin
        if (!pix_logic_reset_n) begin
            hcount <= 0;
            vcount <= 0;
        end else if (hcount == 12'd1649) begin
            hcount <= 0;
            if (vcount == 12'd749) vcount <= 0;
            else vcount <= vcount + 1'b1;
        end else hcount <= hcount + 1'b1;
    end

    wire hs = hcount < 12'd40;
    wire vs = vcount < 12'd5;
    wire de = hcount >= 12'd260 && hcount < 12'd1540 &&
              vcount >= 12'd25 && vcount < 12'd745;
    wire [11:0] x = hcount - 12'd260;
    wire [11:0] y = vcount - 12'd25;
    wire frame_start = (hcount == 0 && vcount == 0);
    wire [7:0] r,g,b;
    video_wb_overlay core(
        .cpu_clk(cpu_clk),.cpu_rst(cpu_rst),
        .wb_cyc_i(wb_cyc_i),.wb_stb_i(wb_stb_i),.wb_we_i(wb_we_i),
        .wb_adr_i(wb_adr_i),.wb_dat_i(wb_dat_i),.wb_sel_i(wb_sel_i),
        .wb_dat_o(wb_dat_o),.wb_ack_o(wb_ack_o),.wb_err_o(wb_err_o),
        .pix_clk(pix_clk),.pix_rst(!pix_logic_reset_n),.frame_start(frame_start),
        .pix_de(de),.pix_x(x),.pix_y(y),.pix_r(r),.pix_g(g),.pix_b(b)
    );
    // EX20-05.4: one-cycle synchronous video pipeline.
    // RGB and timing control signals have identical latency.
    reg [7:0] pix_r_q = 8'd0;
    reg [7:0] pix_g_q = 8'd0;
    reg [7:0] pix_b_q = 8'd0;
    reg pix_hs_q = 1'b0;
    reg pix_vs_q = 1'b0;
    reg pix_de_q = 1'b0;

    always @(posedge pix_clk or negedge pix_logic_reset_n) begin
        if (!pix_logic_reset_n) begin
            pix_r_q  <= 8'd0;
            pix_g_q  <= 8'd0;
            pix_b_q  <= 8'd0;
            pix_hs_q <= 1'b0;
            pix_vs_q <= 1'b0;
            pix_de_q <= 1'b0;
        end else begin
            pix_r_q  <= r;
            pix_g_q  <= g;
            pix_b_q  <= b;
            pix_hs_q <= hs;
            pix_vs_q <= vs;
            pix_de_q <= de;
        end
    end
    DVI_TX_Top dvi (
        .I_rst_n(pix_reset_n),.I_serial_clk(serial_clk),.I_rgb_clk(pix_clk),
        .I_rgb_vs(pix_vs_q),.I_rgb_hs(pix_hs_q),.I_rgb_de(pix_de_q),
        .I_rgb_r(pix_r_q),.I_rgb_g(pix_g_q),.I_rgb_b(pix_b_q),
        .O_tmds_clk_p(tmds_clk_p),.O_tmds_clk_n(tmds_clk_n),
        .O_tmds_data_p(tmds_data_p),.O_tmds_data_n(tmds_data_n)
    );
endmodule
