// PiKoSoL GPIO extension for Tang Primer 20K Dock V3714.
// 0x80000020 PMOD1_OUT RW; 0x24 IN RO; 0x28 DIR RW
// 0x80000030 PMOD2_OUT RW; 0x34 IN RO; 0x38 DIR RW
// 0x80000040 PMOD3_OUT RW; 0x44 IN RO; 0x48 DIR RW
// 0x80000050 LED_OUT RW (bits 0..5, logical 1 = LED ON)
// 0x80000054 KEY_IN RO (bits 0..2, S2/S3/S5; 1 = pressed)
// 0x80000058 DIP_RAW RO (bits 0..3, SW2..SW5 raw levels)
// 0x8000005C GPIO_ID RO (0x47503134, "GP14")
// PMOD0 legacy 0x80000000 output remains independent and unchanged.
import picorv32_bus_pkg::*;
module tp20_gpio_v3714 (
    input wire clk, reset_n,
    input rv32_req_t req,
    output rv32_resp_t resp,
    inout wire [7:0] pmod1, pmod2, pmod3,
    input wire [2:0] buttons_n,
    input wire [3:0] dips_raw,
    output reg [5:0] led_out
);
    reg [7:0] out1, out2, out3;
    reg [7:0] dir1, dir2, dir3;
    wire [7:0] in1, in2, in3;
    genvar i;
    generate for (i=0; i<8; i=i+1) begin : gpio_pins
        assign pmod1[i] = dir1[i] ? out1[i] : 1'bz;
        assign pmod2[i] = dir2[i] ? out2[i] : 1'bz;
        assign pmod3[i] = dir3[i] ? out3[i] : 1'bz;
    end endgenerate
    assign in1 = pmod1;
    assign in2 = pmod2;
    assign in3 = pmod3;

    reg [7:0] in1meta, in1sync, in2meta, in2sync, in3meta, in3sync;
    reg [2:0] key_meta, key_sync;
    reg [3:0] dip_meta, dip_sync;
    reg ready;
    wire write_enable = req.select && req.wstrb[0] && !ready;
    // Offset from 0x80000020, indexed by physical word address [5:2].
    wire [3:0] index = req.addr[5:2] - 4'd8;
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            out1 <= 0; out2 <= 0; out3 <= 0;
            dir1 <= 0; dir2 <= 0; dir3 <= 0; // Hi-Z on reset
            led_out <= 0;
            in1meta <= 0; in1sync <= 0;
            in2meta <= 0; in2sync <= 0;
            in3meta <= 0; in3sync <= 0;
            key_meta <= 0; key_sync <= 0;
            dip_meta <= 0; dip_sync <= 0;
            ready <= 0;
        end else begin
            in1meta <= in1; in1sync <= in1meta;
            in2meta <= in2; in2sync <= in2meta;
            in3meta <= in3; in3sync <= in3meta;
            key_meta <= ~buttons_n; key_sync <= key_meta;
            dip_meta <= dips_raw; dip_sync <= dip_meta;
            ready <= req.select;
            if (write_enable) begin
                case (index)
                    4'd0: out1 <= req.wdata[7:0];
                    4'd2: dir1 <= req.wdata[7:0];
                    4'd4: out2 <= req.wdata[7:0];
                    4'd6: dir2 <= req.wdata[7:0];
                    4'd8: out3 <= req.wdata[7:0];
                    4'd10: dir3 <= req.wdata[7:0];
                    4'd12: led_out <= req.wdata[5:0];
                    default: ; // inputs and ID are read-only
                endcase
            end
        end
    end
    reg [31:0] value;
    always @* begin
        case (index)
            4'd0:  value = {24'b0, out1};
            4'd1:  value = {24'b0, in1sync};
            4'd2:  value = {24'b0, dir1};
            4'd4:  value = {24'b0, out2};
            4'd5:  value = {24'b0, in2sync};
            4'd6:  value = {24'b0, dir2};
            4'd8:  value = {24'b0, out3};
            4'd9:  value = {24'b0, in3sync};
            4'd10: value = {24'b0, dir3};
            4'd12: value = {26'b0, led_out};
            4'd13: value = {29'b0, key_sync};
            4'd14: value = {28'b0, dip_sync};
            4'd15: value = 32'h47503134;
            default: value = 32'b0;
        endcase
    end
    assign resp.rdata = req.select ? value : 32'b0;
    assign resp.ready = ready;
endmodule
