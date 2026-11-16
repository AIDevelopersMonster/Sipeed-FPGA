// PiKoSoL 25K console: single-write-port, synchronous-read VRAM candidate.
// Engineering RTL only. No Gowin BUILD PASS or BOARD PASS is claimed.
// 80 columns x 30 rows x 8 bits = 19200 data bits.
module pikosol_vram_80x30 (
    input  wire        clk,
    input  wire        we,
    input  wire [11:0] waddr,
    input  wire [7:0]  wdata,
    input  wire [11:0] raddr,
    output reg  [7:0]  rdata
);
    localparam integer DEPTH = 2400;
    (* syn_ramstyle = "block_ram" *)
    reg [7:0] mem [0:DEPTH-1];

    // No reset or full-array initialization in this block.
    // The controller must clear the screen through the write port
    // before using any uninitialized characters.
    // Registered read: one clock latency.
    // Read-during-write to identical address is device/tool-dependent;
    // arbitration must avoid relying on its returned value.
    always @(posedge clk) begin
        if (we && waddr < DEPTH)
            mem[waddr] <= wdata;
        if (raddr < DEPTH)
            rdata <= mem[raddr];
        else
            rdata <= 8'h20;
    end
endmodule
