# Tang Primer 20K — FPGA / RISC-V Processor Laboratory

**Board:** Sipeed Tang Primer 20K + Dock  
**FPGA family:** GOWIN GW2A-LV18 (exact package, speed grade and board revision to verify on hardware)  
**Scope:** own CPU/SoC experiments, FPGA peripherals, video, memory, and adaptation of PiKoSoL/KonSol.

**Status: JTAG SCAN PASS (2026-11-18); PR20-03 PiKoSoL HDMI/UART/GPIO BOARD PASS (2026-11-22), scoped to the operator-tested configuration.** One GW2A-family device was detected as ID 0x0000081B. This directory is for **Tang Primer 20K**, NOT Tang Primer 25K (GW5A-LV25) and NOT Tang Nano 20K. No bitstream, synthesis result, timing result, or general BOARD PASS is claimed here.

## Start here

- [Начало работы и план (RU)](START_HERE_RU.md)
- [Hardware / pinout evidence](Hardware/README.md)
- [PR20-00 — Board Bring-up](Examples/PR20-00-Board-Bringup/README.md)
- [PR20-01 — PicoRV32 port](Examples/PR20-01-PicoRV32/README.md)
- [PR20-02 — LiteX / VexRiscv](Examples/PR20-02-LiteX-VexRiscv/README.md)
- [PR20-03 — PiKoSoL / KonSol](Examples/PR20-03-PiKoSoL-KonSol/README.md)
- [GPIO / PMOD V3714 — 32 линии, pinout, Verilog, 5 проверенных BIN](Examples/PR20-03-PiKoSoL-KonSol/GPIO-PMOD-V3714/README.md)
- [TP20-01 — JTAG scan: read-only PASS, script and sanitized example](Tests/TP20-01-JTAG/README.md)
- [TP20-02 — HDMI 1280×720: official Sipeed dk_video.fs + video demo](Tests/TP20-02-HDMI/README.md)
- [RTL](RTL/README.md) · [Tests](Tests/README.md) · [Tools](Tools/README.md) · [Documentation](Documentation/README.md)

## Official HDMI example / video (2026-11-18)

The [TP20-02 HDMI experiment README](Tests/TP20-02-HDMI/README.md) links to the [operator-supplied YouTube Shorts video](https://youtube.com/shorts/-JyNlnzaJZ0), the **unmodified official Sipeed `dk_video.fs`** bitstream and the original Verilog/Gowin project. The original ready-made bitstream is **not our build** and is not redistributed in this repository. A full HDMI BOARD PASS with log and local file hash is not claimed by this entry.

## Development principles

1. The computer and its processor architecture are the primary research targets; games are optional application demonstrations.
2. Reuse **design ideas and independently verified portable components** from Tang Nano 9K/20K; never copy constraints, PLL settings, pin maps, or board test status.
3. Start with the native Dock and a minimal reproducible board bring-up; document exact fitted DDR3, Flash, and interfaces before building assumptions around them.
4. Keep hardware facts, tool reports, simulations, and on-board observations distinguishable.
5. Prefer temporary SRAM configuration for initial testing; Flash writes require backup and a recovery procedure.

## Planned modules

| ID | Topic | State |
| --- | --- | --- |
| PR20-00 | Board identification, clock, JTAG, LED, UART, RAM | JTAG SCAN PASS; remaining tests NOT TESTED |
| PR20-01 | PicoRV32 and a small memory-mapped SoC | PLAN |
| PR20-02 | VexRiscv/LiteX and comparison with a common workload | PLAN |
| PR20-03 | PiKoSoL: UART, HDMI, GPIO V3714 / PMOD | BOARD PASS: scoped to the verified files/physical ports in [GPIO-PMOD-V3714](Examples/PR20-03-PiKoSoL-KonSol/GPIO-PMOD-V3714/README.md) |

A successful simulation or build is **not** a BOARD PASS. Results from the Primer 25K or Nano 20K must not be attributed to this board.

## Manufacturer resources

- [Sipeed Wiki — Tang Primer 20K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html)
- [Sipeed example repository](https://github.com/sipeed/TangPrimer-20K-example)
- [Youyeetoo support wiki](https://wiki.youyeetoo.com/)

These are reference entry points, not proof that any example has been tested on our hardware.
