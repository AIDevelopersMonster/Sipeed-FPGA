#!/usr/bin/env python3
"""EX20-05 integrated VexRiscv + Wishbone video + 720p HDMI.
Prototype integration: build/STA and board not yet verified.
Never flashes or programs FPGA. This script only generates/builds locally.
"""
import argparse
from pathlib import Path

from migen import Instance, Pins, IOStandard, ClockSignal, ResetSignal
from litex.soc.interconnect import wishbone
from litex.soc.integration.builder import Builder
from litex.soc.integration.soc import SoCRegion
from litex_boards.targets.sipeed_tang_nano_20k import BaseSoC

ROOT = Path(__file__).resolve().parent
VIDEO_BASE = 0xB1000000
# Physical locations from official Sipeed HDMI hdmi.cst for GW2AR-LV18QN88C8/I7.
# DVI TX generates differential signals. Pin/IO constraints require Gowin PNR review.
HDMI_IO = [
    ("O_tmds_clk_p", 0, Pins("33"), IOStandard("LVDS25")),
    ("O_tmds_clk_n", 0, Pins("34"), IOStandard("LVDS25")),
    ("O_tmds_data_p", 0, Pins("35 37 39"), IOStandard("LVDS25")),
    ("O_tmds_data_n", 0, Pins("36 38 40"), IOStandard("LVDS25")),
]


def build_soc(args):
    soc = BaseSoC(
        sys_clk_freq=48e6,
        with_led_chaser=False,
        with_rgb_led=False,
        with_buttons=False,
        cpu_type="vexriscv",
        cpu_variant="minimal",
        uart_name="serial",
    )
    platform = soc.platform
    platform.add_extension(HDMI_IO)
    # Make all HDMI pins part of this build and fail before any board action if
    # platform constraint generation or Gowin route does not support the pairs.
    clk_p = platform.request("O_tmds_clk_p")
    clk_n = platform.request("O_tmds_clk_n")
    data_p = platform.request("O_tmds_data_p")
    data_n = platform.request("O_tmds_data_n")

    sources = [
        ROOT / "rtl" / "video_wb_overlay.v",
        ROOT / "rtl" / "video_hdmi_bridge.v",
        ROOT / "vendor" / "TMDS_rPLL.v",
        ROOT / "vendor" / "dvi_tx.v",
    ]
    for source in sources:
        if not source.is_file():
            raise FileNotFoundError(
                f"{source} missing. Obtain upstream vendor files with prepare_vendor.ps1"
            )
        platform.add_source(str(source))

    bus = wishbone.Interface(data_width=32, adr_width=30)
    soc.bus.add_slave(
        name="video",
        slave=bus,
        region=SoCRegion(origin=VIDEO_BASE, size=0x100, cached=False),
    )
    # Wishbone adr is WORD addressed; RTL expects byte offset within peripheral.
    # 64 words * 4 bytes = 256 byte bus region.
    # The CPU must not access video in the original factory ROM configuration.
    from migen import Cat, Constant
    soc.specials += Instance(
        "video_hdmi_bridge",
        i_clk27=platform.request("clk27"),
        i_cpu_clk=ClockSignal("sys"),
        i_cpu_rst=ResetSignal("sys"),
        i_wb_cyc_i=bus.cyc,
        i_wb_stb_i=bus.stb,
        i_wb_we_i=bus.we,
        i_wb_adr_i=Cat(Constant(0, 2), bus.adr[:6]),
        i_wb_dat_i=bus.dat_w,
        i_wb_sel_i=bus.sel,
        o_wb_dat_o=bus.dat_r,
        o_wb_ack_o=bus.ack,
        o_wb_err_o=bus.err,
        o_tmds_clk_p=clk_p,
        o_tmds_clk_n=clk_n,
        o_tmds_data_p=data_p,
        o_tmds_data_n=data_n,
    )
    # Leave video_locked unconnected for now; no external bitstream loading.
    soc.add_constant("VIDEO_BASE", VIDEO_BASE)
    return soc


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--build", action="store_true",
        help="Run Gowin synth/PNR, after generating LiteX SoC"
    )
    parser.add_argument(
        "--output-dir", type=str,
        default=str(ROOT / "build"),
    )
    args = parser.parse_args()
    soc = build_soc(args)
    print(f"EX20-05 target: {soc.platform.device}; VexRiscv + HDMI")
    print(f"Video Wishbone region: 0x{VIDEO_BASE:08X} .. 0x{VIDEO_BASE+0xFF:08X}")
    print("NO SRAM PROGRAMMING; NO FLASH PROGRAMMING")
    builder = Builder(soc, output_dir=args.output_dir, csr_csv=str(Path(args.output_dir)/"csr.csv"))
    builder.build(run=args.build)
    print("EX20-05 DESIGN GENERATED" + (" / Gowin build requested" if args.build else " / Gowin not run"))
    print("CHECK constraints, output .fs, PNR/STA, and resource report before any SRAM-only test.")


if __name__ == "__main__":
    main()
