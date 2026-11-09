`timescale 1ns / 1ps
// EX20-05.15C. Qualifies SYSTEM PLL LOCK, never video PLL LOCK.
// - Asserts release-low asynchronously on POR or loss of LOCK.
// - Waits for two clk27 sampling stages and STABLE_CYCLES clean clocks.
// - Deasserts release synchronously to clk27; the LiteX/Migen
//   AsyncResetSynchronizer then deasserts sys reset synchronously to sys_clk.
module ex20_05_sys_pll_guard #(
    parameter integer STABLE_CYCLES = 4096
) (
    input  wire clk27,
    input  wire por_done,
    input  wire pll_locked,
    output reg  sys_release = 1'b0
);
    wire raw_good = por_done & pll_locked;
    (* async_reg = "true" *) reg lock_meta = 1'b0;
    (* async_reg = "true" *) reg lock_sync = 1'b0;
    reg [11:0] stable_count = 12'd0;

    always @(posedge clk27 or negedge raw_good) begin
        if (!raw_good) begin
            lock_meta    <= 1'b0;
            lock_sync    <= 1'b0;
            stable_count <= 12'd0;
            sys_release  <= 1'b0;
        end else begin
            lock_meta <= 1'b1;
            lock_sync <= lock_meta;
            if (!lock_sync) begin
                stable_count <= 12'd0;
                sys_release <= 1'b0;
            end else if (!sys_release) begin
                if (stable_count == (STABLE_CYCLES - 1)) begin
                    sys_release <= 1'b1;
                end else begin
                    stable_count <= stable_count + 12'd1;
                end
            end
        end
    end
endmodule
