# Sipeed FPGA — CPU/SoC research line

**Current milestone (23 October 2026): PiKoSoL LAB-04.4 — WebUSB + Web Serial, HARDWARE PASS (operator-confirmed).**

[**GitHub Pages: Start**](https://aidevelopersmonster.github.io/Sipeed-FPGA/) · [**1. Program FPGA / WebUSB**](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) · [**2. Control CPU / Web Serial**](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/) · [**Release PiKoSoL v0.2.0**](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0)

Tang Nano 9K / Gowin GW1NR-9C with CHUWI Intel N100 / Windows 11: first-party GitHub Pages fetch of SHA-256-verified `.fs`; WebUSB SRAM programming over FT2232 JTAG A (WinUSB); true PicoRV32 UART terminal over Web Serial FT2232 B (115200 8N1), control of hardware LEDs, HDMI TERM and GFX. Hardware results were reported by the operator; CI verified delivery of the bundled WebAssembly runtime and firmware. This is **not** an exhaustive cross-platform certification. Firmware/RTL not changed for the web controls.

[**LAB-04.4 acceptance report (RU)**](docs/lab04/LAB044_ACCEPTANCE_2026-10-23_RU.md) · [LAB-04.3.2 CPU/HDMI](docs/lab04/README.md) · [WebUSB guide](docs/lab04/web-loader/README.md) · [Web Serial guide](docs/lab04/web-control/README.md).

## Publication / Публикация

The bilingual (RU/EN) technical article describing PiKoSoL architecture, WebUSB SRAM programming, Web Serial control, engineering tools and hardware acceptance is available on Zenodo:

**[PiKoSoL technical article — DOI: 10.5281/zenodo.23593101](https://doi.org/10.5281/zenodo.23593101)**

This publication describes the experimental platform. It is separate from the [firmware v0.2.0 release](https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/pikosol-v0.2.0) and does not change the FPGA bitstream.

**Historical progress follows; the LAB-02 status below is no longer the newest milestone.**


**Current status: PicoRV32 LAB-02 — BOARD_PASS + HTML_HARDWARE_PASS on Tang Nano 9K (20 October 2026).** Earlier P1 is preserved in Git history. Firmware model, RTL simulation, Gowin PnR/STA at 27 MHz, SRAM programming, UART `PICO` and LED animation were confirmed. The four-instruction interactive demonstration below is a separate conceptual example.

One repository; four deliberately independent implementations. Platforms are **Sipeed Tang Nano 9K** and **Tang Primer 25K**. This is **not** the DDF training repository and **not** an Intel MAX 10 project.

| Stage | Folder | CPU/SoC | First target | Current state |
|---|---|---|---|---|
| 01 | [`01-PicoRV32`](01-PicoRV32/README.md) | PicoRV32 (RV32I) | Tang Nano 9K | LAB-04.4 WEBUSB + WEBSERIAL hardware pass (operator); LAB-04.3.2 CPU/HDMI hardware pass; LAB-02 completed 2026-10-20 |
| 02 | [`02-NEORV32`](02-NEORV32/README.md) | NEORV32 (VHDL) | Tang Nano 9K | Research baseline / integration specification |
| 03 | [`03-LiteX-VexRiscv`](03-LiteX-VexRiscv/README.md) | LiteX with VexRiscv | Tang Primer 25K | Research baseline / integration specification |
| 04 | [`04-Rocket`](04-Rocket/README.md) | Rocket RV32IC minimal configuration | Tang Primer 25K | Feasibility study, NOT a confirmed fit |

## Interactive educational demonstration / Интерактивная демонстрация

[**PicoRV32: how one machine instruction turns on LED L1 — HTML RU/EN**](docs/interactive/picorv32-led1/README.md) · 19 steps, local/offline browser, registers, decoder, MMIO and active-low LED output. Separate educational model; not a cycle-accurate Verilog simulator.

## LAB-02: verified board + educational HTML (Windows PowerShell 7)

[**Laboratory 02 — Russian/English methodical guides, PDF and hardware-linked HTML**](docs/lab02/README.md).

The current ROM is the 118-instruction UART controller (`READY`, `L=n`). The earlier 33-instruction `PICO` firmware and the original P1 protocol are preserved in Git history. Run `test_lab02.ps1`, not the earlier P1-specific `test.ps1`, against LAB-02 HEAD.

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\tools\preflight.ps1
& .\01-PicoRV32\tools\test_lab02.ps1 -ModelOnly
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab02.ps1
& .\01-PicoRV32\tools\build_gowin.ps1
```

The full RTL test requires Icarus Verilog (`iverilog` + `vvp`) and a network-connected fetch of the ISC-licensed PicoRV32 source at an exact commit. The Gowin command uses installed `C:\Gowin\Gowin_V1.9.9Beta-4_Education` by default. The independent Windows-based simulation, Gowin build and physical test **passed on 19 October 2026**; record the toolchain and specific build with each new experiment.

The project intentionally does not auto-program any device. To program **volatile SRAM only** (not configuration flash) after checking the `.fs` and logs:

```powershell
$prog = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$fs = (Resolve-Path '.\01-PicoRV32\impl\pnr\picorv32_nano9k.fs').Path
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index 1
$LASTEXITCODE   # expected 0 with the validated FT2CH cable
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

Цель — сравнить четыре способа построения RISC-V-систем на FPGA. Для каждой реализации своя папка, исходники, модель проверки, отчёты по ресурсам и собственная периферия. Общие спецификация, карта регистров и протокол испытаний находятся в `common/` и `docs/`. Первым создаётся минимальный PicoRV32 SoC на Tang Nano 9K с UART, светодиодами и аппаратным счётчиком. Физическая проверка выполнена 19 октября 2026 года: SRAM, UART `PICO` и LED-анимация — PASS.
