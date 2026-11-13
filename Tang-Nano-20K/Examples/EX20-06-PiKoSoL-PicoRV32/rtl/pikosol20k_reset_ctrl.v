// PiKoSoL 20K: independent serializer, CPU and pixel reset release.
// Asynchronous assertion on PLL loss/button; synchronous deassert in each
// destination domain. The three CDC mailboxes reset both endpoints together.
module pikosol20k_reset_ctrl #(
    parameter integer POR_BITS = 16
)(
    input wire clk27,
    input wire serial_clk,
    input wire pix_clk,
    input wire pll_locked,
    input wire reset_btn,
    output wire resetn_cpu,
    output wire resetn_pixel,
    output wire resetn_serializer
);
    wire raw_good = pll_locked && !reset_btn;

    // Three serial edges to release the PHY after PLL lock.
    (* async_reg = "true", syn_keep = 1 *) reg [2:0] ser_release = 0;
    always @(posedge serial_clk or negedge raw_good) begin
        if (!raw_good) ser_release <= 3'b000;
        else ser_release <= {ser_release[1:0], 1'b1};
    end
    assign resetn_serializer = ser_release[2];

    // CPU cannot start (or keep pending CDC toggles) while pixel PLL is
    // unlocked. ROM and UART are released after the power-on qualification.
    wire sys_raw_good = raw_good && resetn_serializer;
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

    wire pixel_raw_good = resetn_serializer && resetn_cpu;
    (* async_reg = "true", syn_keep = 1 *) reg [1:0] pixel_release = 0;
    always @(posedge pix_clk or negedge pixel_raw_good) begin
        if (!pixel_raw_good) pixel_release <= 2'b00;
        else pixel_release <= {pixel_release[0], 1'b1};
    end
    assign resetn_pixel = pixel_release[1];
endmodule
