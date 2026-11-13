// PiKoSoL 20K: independent serializer, CPU and pixel reset release.
// Asynchronous assertion on PLL loss/button; synchronous deassert in each
// destination domain. The three CDC mailboxes reset both endpoints together.
module pikosol20k_reset_ctrl #(
    parameter integer POR_BITS = 16
)(
    input wire clk27,
    input wire pix_clk,
    input wire pll_locked,
    input wire reset_btn,
    output wire resetn_cpu,
    output wire resetn_pixel,
    output wire resetn_serializer
);
    wire raw_good = pll_locked && !reset_btn;

    // Match the official Sipeed Tang Nano 20K / hdmi/src/video_top.v:
    // hdmi4_rst_n = ~I_rst & pll_lock drives BOTH DVI_TX_Top I_rst_n
    // and CLKDIV RESETN. These Gowin IP blocks use an async reset.
    //
    // STA-3's serial-clocked register ser_release[2] became a launch FF
    // for OSER10 RESET at the opposite 371.25-MHz clock edge, violating
    // recovery by 0.672 ns and leaving 4 fast-domain setup endpoints.
    // Driving vendor reset directly from PLL lock removes this fabricated
    // high-speed register-to-asynchronous-reset timing relationship.
    //
    // IMPORTANT: vendor style is not a formal proof of PLL LOCK reset
    // release timing; verify STA and real PLL lock/button cycling before
    // declaring hardware acceptance. No timing exception is added.
    assign resetn_serializer = raw_good;

    // The CPU reset must NOT asynchronously depend on serializer logic,
    // where STA-2 originally had recovery paths to por_count PRESET/CPU
    // CLEAR across unrelated high-speed/27 MHz domains (WNS -2.403 ns).
    // raw_good asynchronously asserts reset; CPU counter and release
    // deassert synchronously under clk27 after power-on qualification.
    wire sys_raw_good = raw_good;
    reg [POR_BITS-1:0] por_count = {POR_BITS{1'b1}};
    (* async_reg = "true", syn_keep = 1 *) reg [1:0] cpu_release = 0;
    always @(posedge clk27 or negedge sys_raw_good) begin
        if (!sys_raw_good) begin
            por_count <= {POR_BITS{1'b1}};
            cpu_release <= 2'b00;
        end else begin
            if (por_count != 0) por_count <= por_count - 1'b1;
            cpu_release <= {cpu_release[0], (por_count == 0)};
        end
    end
    assign resetn_cpu = cpu_release[1];

    // Pixel reset similarly has no asynchronous combinational reset input
    // sourced from CPU or the fast serializer domain. CLKDIV itself is
    // disabled until PLL lock, per the upstream Sipeed wiring.
    wire pixel_raw_good = raw_good;
    (* async_reg = "true", syn_keep = 1 *) reg [1:0] pixel_release = 0;
    always @(posedge pix_clk or negedge pixel_raw_good) begin
        if (!pixel_raw_good) pixel_release <= 2'b00;
        else pixel_release <= {pixel_release[0], 1'b1};
    end
    assign resetn_pixel = pixel_release[1];
endmodule
