# Sipeed FPGA — CPU/SoC research line

**Status: v0.1.0 / bootstrap. CPU sources pinned, PicoRV32 RTL not yet proven on a physical board.**

One repository; four deliberately independent implementations. Platforms are **Sipeed Tang Nano 9K** and **Tang Primer 25K**. This is **not** the DDF training repository and **not** an Intel MAX 10 project.

| Stage | Folder | CPU/SoC | First target | Current state |
|---|---|---|---|---|
| 01 | [`01-PicoRV32`](01-PicoRV32/README.md) | PicoRV32 (RV32I) | Tang Nano 9K | Source boot demo + firmware model test |
| 02 | [`02-NEORV32`](02-NEORV32/README.md) | NEORV32 (VHDL) | Tang Nano 9K | Research baseline / integration specification |
| 03 | [`03-LiteX-VexRiscv`](03-LiteX-VexRiscv/README.md) | LiteX with VexRiscv | Tang Primer 25K | Research baseline / integration specification |
| 04 | [`04-Rocket`](04-Rocket/README.md) | Rocket RV32IC minimal configuration | Tang Primer 25K | Feasibility study, NOT a confirmed fit |

## First experiment (Windows PowerShell 7)

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\tools\preflight.ps1
& .\01-PicoRV32\tools\test.ps1 -PythonOnly
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test.ps1
& .\01-PicoRV32\tools\build_gowin.ps1
```

The full RTL test requires Icarus Verilog (`iverilog` + `vvp`) and a network-connected fetch of the ISC-licensed PicoRV32 source at an exact commit. The Gowin command uses installed `C:\Gowin\Gowin_V1.9.9Beta-4_Education` by default. **Do not claim RTL or board PASS until the corresponding commands and measurements succeed.**

The project intentionally does not auto-program any device. To program **volatile SRAM only** (not configuration flash) after checking the `.fs` and logs:

```powershell
& .\01-PicoRV32\tools\program_sram.ps1 -Bitstream 'C:\full\path\to\picorv32_nano9k.fs'
```

## Scientific engineering policy

- Independent RTL/ISA specification and common MMIO semantics (`common/`).
- Native buses remain CPU-specific; adapt them at the boundary, do not falsify their equivalence.
- Record tool versions, commits, clock constraints, resource reports, and measured board evidence.
- Compare common ISA baseline (RV32I) where practical; record optional features separately.
- **No invented FPGA LUT, FF, BRAM, Fmax, power or cycle measurements.**
- Third-party IP lives in ignored vendor directories, pinned by [`sources.lock.json`](sources.lock.json). License obligations of each upstream project apply.

More: [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md), [`docs/TEST_PROTOCOL.md`](docs/TEST_PROTOCOL.md), [`docs/ROADMAP.md`](docs/ROADMAP.md).

---

## Кратко по-русски

Цель — сравнить четыре способа построения RISC-V-систем на FPGA. Для каждой реализации своя папка, исходники, модель проверки, отчёты по ресурсам и собственная периферия. Общие спецификация, карта регистров и протокол испытаний находятся в `common/` и `docs/`. Первым создаётся минимальный PicoRV32 SoC на Tang Nano 9K с UART, светодиодами и аппаратным счётчиком. Физическая проверка пока не проводилась.
