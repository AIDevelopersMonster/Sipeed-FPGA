// 1 kHz sine at 48 kHz: one stereo sample strobe every 562.5 pixel clocks (27 MHz),
// 48 samples per cycle, amplitude 8192 (-12 dBFS).
module tone_1k #(
    parameter integer CLK_HZ   = 27_000_000,
    parameter integer AUDIO_HZ = 48_000
) (
    input  wire        clk,
    input  wire        rst_n,
    output reg         valid = 1'b0,
    output reg  [15:0] sample = 16'd0
);
    reg [24:0] acc = 0;     // fractional divider: alternates 562 / 563 clocks
    reg [5:0]  idx = 0;

    function [15:0] sine_lut(input [5:0] i);
        case (i)
            6'd0: sine_lut = 16'h0000;  // 0
            6'd1: sine_lut = 16'h042D;  // 1069
            6'd2: sine_lut = 16'h0848;  // 2120
            6'd3: sine_lut = 16'h0C3F;  // 3135
            6'd4: sine_lut = 16'h1000;  // 4096
            6'd5: sine_lut = 16'h137B;  // 4987
            6'd6: sine_lut = 16'h16A1;  // 5793
            6'd7: sine_lut = 16'h1963;  // 6499
            6'd8: sine_lut = 16'h1BB6;  // 7094
            6'd9: sine_lut = 16'h1D90;  // 7568
            6'd10: sine_lut = 16'h1EE9;  // 7913
            6'd11: sine_lut = 16'h1FBA;  // 8122
            6'd12: sine_lut = 16'h2000;  // 8192
            6'd13: sine_lut = 16'h1FBA;  // 8122
            6'd14: sine_lut = 16'h1EE9;  // 7913
            6'd15: sine_lut = 16'h1D90;  // 7568
            6'd16: sine_lut = 16'h1BB6;  // 7094
            6'd17: sine_lut = 16'h1963;  // 6499
            6'd18: sine_lut = 16'h16A1;  // 5793
            6'd19: sine_lut = 16'h137B;  // 4987
            6'd20: sine_lut = 16'h1000;  // 4096
            6'd21: sine_lut = 16'h0C3F;  // 3135
            6'd22: sine_lut = 16'h0848;  // 2120
            6'd23: sine_lut = 16'h042D;  // 1069
            6'd24: sine_lut = 16'h0000;  // 0
            6'd25: sine_lut = 16'hFBD3;  // -1069
            6'd26: sine_lut = 16'hF7B8;  // -2120
            6'd27: sine_lut = 16'hF3C1;  // -3135
            6'd28: sine_lut = 16'hF000;  // -4096
            6'd29: sine_lut = 16'hEC85;  // -4987
            6'd30: sine_lut = 16'hE95F;  // -5793
            6'd31: sine_lut = 16'hE69D;  // -6499
            6'd32: sine_lut = 16'hE44A;  // -7094
            6'd33: sine_lut = 16'hE270;  // -7568
            6'd34: sine_lut = 16'hE117;  // -7913
            6'd35: sine_lut = 16'hE046;  // -8122
            6'd36: sine_lut = 16'hE000;  // -8192
            6'd37: sine_lut = 16'hE046;  // -8122
            6'd38: sine_lut = 16'hE117;  // -7913
            6'd39: sine_lut = 16'hE270;  // -7568
            6'd40: sine_lut = 16'hE44A;  // -7094
            6'd41: sine_lut = 16'hE69D;  // -6499
            6'd42: sine_lut = 16'hE95F;  // -5793
            6'd43: sine_lut = 16'hEC85;  // -4987
            6'd44: sine_lut = 16'hF000;  // -4096
            6'd45: sine_lut = 16'hF3C1;  // -3135
            6'd46: sine_lut = 16'hF7B8;  // -2120
            6'd47: sine_lut = 16'hFBD3;  // -1069
            default: sine_lut = 16'h0000;
        endcase
    endfunction
    wire [15:0] sine = sine_lut(idx);   // continuous assign: defined from time 0 in sim

    always @(posedge clk) begin
        valid <= 1'b0;
        if (!rst_n) begin
            acc <= 0;
            idx <= 0;
        end else if (acc + AUDIO_HZ >= CLK_HZ) begin
            acc    <= acc + AUDIO_HZ - CLK_HZ;
            valid  <= 1'b1;
            sample <= sine;
            idx    <= (idx == 6'd47) ? 6'd0 : idx + 1'b1;
        end else
            acc <= acc + AUDIO_HZ;
    end
endmodule
