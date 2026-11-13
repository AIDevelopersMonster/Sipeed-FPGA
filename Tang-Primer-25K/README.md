# Tang Primer 25K — Processor Research Laboratory

**Board:** Sipeed Tang Primer 25K + Dock  
**Focus:** RISC-V processor architectures, SoC integration, memory, buses, and reproducible FPGA measurements.

> Project skeleton only. No synthesis, timing, or BOARD PASS claims have been made for Primer 25K.

## Start here

**[Практический порядок: PMOD → DVI → TF → USB → контроллеры → CPU → ОС → игры](QUICK_START_PLAN.md)**


- [Начало работы (RU)](START_HERE_RU.md)
- [Hardware baseline](Hardware/README.md)
- [PMOD: modules and inventory](PMOD/README.md) — [TF / microSD (available)](PMOD/TF/README.md)
- [PR25-00: Board Bring-up](Examples/PR25-00-Board-Bringup/README.md)
- [PR25-01: PicoRV32](Examples/PR25-01-PicoRV32/README.md)
- [PR25-02: VexRiscv](Examples/PR25-02-VexRiscv/README.md)
- [PR25-03: RV32I Core](Examples/PR25-03-RV32I-Core/README.md)
- [RTL](RTL/README.md) · [Tests](Tests/README.md) · [Tools](Tools/README.md) · [Documentation](Documentation/README.md)

## Research rules

1. Keep board-specific sources and constraints within this directory.
2. Use the same workloads and documented conditions when comparing CPU cores.
3. Report SIM PASS, BUILD PASS, STA PASS, and BOARD PASS separately.
4. Default to volatile SRAM programming; do not modify configuration Flash without a documented recovery procedure.
5. Do not assume an external SDRAM module is installed merely because the Dock is present.

**State:** STRUCTURE ONLY / NOT TESTED.
