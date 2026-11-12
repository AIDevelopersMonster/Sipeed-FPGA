# Tang Primer 20K — FPGA / RISC-V Processor Laboratory

**Board:** Sipeed Tang Primer 20K + Dock  
**FPGA family:** GOWIN GW2A-LV18 (exact package, speed grade and board revision to verify on hardware)  
**Scope:** own CPU/SoC experiments, FPGA peripherals, video, memory, and adaptation of PiKoSoL/KonSol.

**Status: STRUCTURE ONLY / NOT TESTED.** This directory is for **Tang Primer 20K**, NOT Tang Primer 25K (GW5A-LV25) and NOT Tang Nano 20K. No bitstream, synthesis result, timing result, or BOARD PASS is claimed here.

## Start here

- [Начало работы и план (RU)](START_HERE_RU.md)
- [Hardware / pinout evidence](Hardware/README.md)
- [PR20-00 — Board Bring-up](Examples/PR20-00-Board-Bringup/README.md)
- [PR20-01 — PicoRV32 port](Examples/PR20-01-PicoRV32/README.md)
- [PR20-02 — LiteX / VexRiscv](Examples/PR20-02-LiteX-VexRiscv/README.md)
- [PR20-03 — PiKoSoL / KonSol](Examples/PR20-03-PiKoSoL-KonSol/README.md)
- [RTL](RTL/README.md) · [Tests](Tests/README.md) · [Tools](Tools/README.md) · [Documentation](Documentation/README.md)

## Development principles

1. The computer and its processor architecture are the primary research targets; games are optional application demonstrations.
2. Reuse **design ideas and independently verified portable components** from Tang Nano 9K/20K; never copy constraints, PLL settings, pin maps, or board test status.
3. Start with the native Dock and a minimal reproducible board bring-up; document exact fitted DDR3, Flash, and interfaces before building assumptions around them.
4. Keep hardware facts, tool reports, simulations, and on-board observations distinguishable.
5. Prefer temporary SRAM configuration for initial testing; Flash writes require backup and a recovery procedure.

## Planned modules

| ID | Topic | State |
| --- | --- | --- |
| PR20-00 | Board identification, clock, JTAG, LED, UART, RAM | NOT TESTED |
| PR20-01 | PicoRV32 and a small memory-mapped SoC | PLAN |
| PR20-02 | VexRiscv/LiteX and comparison with a common workload | PLAN |
| PR20-03 | PiKoSoL/KonSol: terminal, graphics, program/file transfer | PLAN |

A successful simulation or build is **not** a BOARD PASS. Results from the Primer 25K or Nano 20K must not be attributed to this board.

## Manufacturer resources

- [Sipeed Wiki — Tang Primer 20K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html)
- [Sipeed example repository](https://github.com/sipeed/TangPrimer-20K-example)
- [Youyeetoo support wiki](https://wiki.youyeetoo.com/)

These are reference entry points, not proof that any example has been tested on our hardware.
