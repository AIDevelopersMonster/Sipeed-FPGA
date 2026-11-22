#!/usr/bin/env python3
"""Patch exact THLN33 TP20 PicoRV32 upstream tree, preserving legacy PMOD0.
V3714 Dock only. Source changes are fail-closed; never write working bitstreams.
"""
from pathlib import Path
import sys

root = Path(sys.argv[1]).resolve()

def patch(name, changes):
    file = root / name
    source = file.read_text(encoding='utf-8')
    for old, new in changes:
        count = source.count(old)
        if count != 1:
            raise RuntimeError(f'{name}: expected exactly one anchor, got {count}: {old[:85]!r}')
        source = source.replace(old, new, 1)
    file.write_text(source, encoding='utf-8')
    print('PATCHED:', name)

# Legacy PMOD0 is at 0x80000000. Its existing 0x80000004 input word
# was unreachable because upstream decoded only four bytes.
patch('src/bus_interconnect.sv', [
    ("parameter PORT_SIZE             = 32'd4;        // 1 words, 4 bytes",
     "parameter PORT_SIZE             = 32'd8;        // legacy PMOD0 OUT / IN"),
    ('input  rv32_resp_t port_resp,',
     'input  rv32_resp_t port_resp,\n\n        output rv32_req_t gpio_req,\n        input  rv32_resp_t gpio_resp,'),
    ("parameter PORT_ADDR             = 32'h8000_0000;",
     "parameter GPIO_ADDR             = 32'h8000_0020;\n    parameter GPIO_SIZE             = 32'd64;\n\n    parameter PORT_ADDR             = 32'h8000_0000;"),
    ('assign port_sel = ((cpu_req.addr & ~(PORT_SIZE-1)) == PORT_ADDR);',
     'assign port_sel = ((cpu_req.addr & ~(PORT_SIZE-1)) == PORT_ADDR);\n    wire gpio_sel = (cpu_req.addr >= GPIO_ADDR) && (cpu_req.addr < GPIO_ADDR + GPIO_SIZE);'),
    ('        ram_video_req           = cpu_req;',
     '        gpio_req                = cpu_req;\n        gpio_req.select         = cpu_req.select && gpio_sel;\n\n        ram_video_req           = cpu_req;'),
    ('        else if (port_sel)\n            cpu_resp = port_resp;',
     '        else if (port_sel)\n            cpu_resp = port_resp;\n        else if (gpio_sel)\n            cpu_resp = gpio_resp;'),
])

patch('src/main_system.sv', [
    ('output wire [7:0]   port_out,',
     '''output wire [7:0]   port_out,
        inout wire [7:0] pmod1,
        inout wire [7:0] pmod2,
        inout wire [7:0] pmod3,
        output wire [5:0] led_out,
        input wire [2:0] buttons_n,
        input wire [3:0] dips_raw,'''),
    ('rv32_resp_t port_resp;',
     'rv32_resp_t port_resp;\n    rv32_req_t gpio_req;\n    rv32_resp_t gpio_resp;'),
    ('.port_resp(port_resp),',
     '.port_resp(port_resp),\n        .gpio_req(gpio_req),\n        .gpio_resp(gpio_resp),'),
    ('    /* HDMI */',
     '''    tp20_gpio_v3714 gpio_inst0 (
        .clk(clk), .reset_n(reset_n),
        .req(gpio_req), .resp(gpio_resp),
        .pmod1(pmod1), .pmod2(pmod2), .pmod3(pmod3),
        .buttons_n(buttons_n), .dips_raw(dips_raw),
        .led_out(led_out)
    );

    /* HDMI */'''),
])

patch('src/boards/tp20k/top_board_tp20k.v', [
    ('            input wire        btn_n3,\n', ''),
    ('            input wire        btn_n4,',
     '            input wire        btn_n4,\n            input wire [3:0] dip_2_5,'),
    ('            inout wire [7:0] pmod2,',
     '            inout wire [7:0] pmod2,\n            inout wire [7:0] pmod3,'),
    ("    assign led0 =  1'b0;\n    assign led1 =  1'b0;",
     '''    wire [5:0] gpio_led;
    // Physical LED0=C13, LED1=A13, LED2=N16,
    // LED3=N14, LED4=L14, LED5=L16. Active LOW.
    // Original top signal labels are reversed relative to physical labels.
    assign led5 = ~gpio_led[0];
    assign led4 = ~gpio_led[1];
    assign led3 = ~gpio_led[2];
    assign led2 = ~gpio_led[3];
    assign led1 = ~gpio_led[4];
    assign led0 = ~gpio_led[5];'''),
    ('    main_system (', '    main_system main_system_inst0 ('),
    ('        .port_in(),\n        .port_out(leds_o),',
     '''        .port_in(pmod0),
        .port_out(leds_o),
        .pmod1(pmod1), .pmod2(pmod2), .pmod3(pmod3),
        .led_out(gpio_led),
        .buttons_n({btn_n4, btn_n2, btn_n1}),
        .dips_raw(dip_2_5),'''),
])
# Critical original line: `assign pmod0 = ~leds_o;` remains unchanged.

patch('src/boards/tp20k/sipeed_tang_primer_20k.cst', [
    ('IO_LOC "btn_n3" D7;\nIO_PORT "btn_n3" IO_TYPE=LVCMOS15;\n',
     '// V3714: S4 is FPGA RECONFIG; do not attach D7 as a button.\n'),
    ('IO_PORT "btn_n4" IO_TYPE=LVCMOS15;',
     '''IO_PORT "btn_n4" IO_TYPE=LVCMOS15;

// V3714: read SW2..SW5, 1.5V IO bank; raw physical levels.
IO_LOC "dip_2_5[0]" E9;
IO_PORT "dip_2_5[0]" IO_TYPE=LVCMOS15;
IO_LOC "dip_2_5[1]" E8;
IO_PORT "dip_2_5[1]" IO_TYPE=LVCMOS15;
IO_LOC "dip_2_5[2]" T4;
IO_PORT "dip_2_5[2]" IO_TYPE=LVCMOS15;
IO_LOC "dip_2_5[3]" T5;
IO_PORT "dip_2_5[3]" IO_TYPE=LVCMOS15;'''),
    ('IO_PORT "pmod2[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;',
     '''IO_PORT "pmod2[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8 BANK_VCCIO=3.3;

// PMOD3 (RGB LCD J5 shared), no simultaneous RGB LCD use.
IO_LOC "pmod3[0]" L9;
IO_PORT "pmod3[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[1]" N8;
IO_PORT "pmod3[1]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[2]" N9;
IO_PORT "pmod3[2]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[3]" N7;
IO_PORT "pmod3[3]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[4]" N6;
IO_PORT "pmod3[4]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[5]" D11;
IO_PORT "pmod3[5]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[6]" A11;
IO_PORT "pmod3[6]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;
IO_LOC "pmod3[7]" B11;
IO_PORT "pmod3[7]" IO_TYPE=LVCMOS33 PULL_MODE=UP DRIVE=8;'''),
])
patch('src/boards/tp20k/config.vh', [
    ('`define BUTTONS_NB      0', '`define BUTTONS_NB      3'),
])
patch('tp20k_System_picorv32.gprj', [
    ('<File path="src/peripherals/port.sv" type="file.verilog" enable="1"/>',
     '<File path="src/peripherals/port.sv" type="file.verilog" enable="1"/>\n        <File path="src/peripherals/tp20_gpio_v3714.sv" type="file.verilog" enable="1"/>'),
])

rtl = r'''// PiKoSoL GPIO extension for Tang Primer 20K Dock V3714.
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
'''
(root / 'src/peripherals/tp20_gpio_v3714.sv').write_text(rtl, encoding='utf-8')
print('PATCH COMPLETE: PMOD0 unchanged; PMOD1-3 bidirectional; LED6 output; S2/S3/S5 and SW2-SW5 input')
