# Sipeed FPGA — CPU/SoC research line

**Current PicoRV32 status (22 October 2026):** LAB-02 physical UART/LED test and LAB-03 physical T3 capture (12 snapshots) are recorded; LAB-03.4 independently audited matching **accepted-bus core event sequences** for commands `0` and `4` between RTL/Icarus and Tang Nano 9K. This is *not* cycle, retirement or formal whole-SoC equivalence. See [final LAB-03.4 audit](docs/lab03/LAB03_4_FINAL_AUDIT_20261022_RU.md).

One repository; four deliberately independent implementations. Platforms are **Sipeed Tang Nano 9K** and **Tang Primer 25K**. This is **not** the DDF training repository and **not** an Intel MAX 10 project.

| Stage | Folder | CPU/SoC | First target | Current state |
|---|---|---|---|---|
| 01 | [`01-PicoRV32`](01-PicoRV32/README.md) | PicoRV32 (RV32I) | Tang Nano 9K | LAB-02 BOARD/HTML PASS; LAB-03 T3 physical capture; LAB-03.4 accepted-bus core comparison PASS for `0` and `4` |
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

## LAB-03: PicoRV32 Observatory, Calc и QuizLab

В ветке [`feature/picorv32-lab03-uart-trace`](https://github.com/AIDevelopersMonster/Sipeed-FPGA/tree/feature/picorv32-lab03-uart-trace) опубликован аппаратный эксперимент LAB-03 для Tang Nano 9K (PicoRV32, RV32I) и автономные учебные приложения:

- [Аппаратный Trace Observatory v1.1.0](docs/lab03/observatory/README_RU.md) — трассы шины, реальные измерения и методические материалы.
- [LibreOffice Calc / Excel Observatory v1.1](docs/lab03/calc/README.md) — 32-битные поля инструкций, ROM, модель MMIO, пошаговое воспроизведение событий.
- [PicoRV32 QuizLab v1.0](docs/lab03/quizlab/README.md) — HTML-квиз в стиле QuizLaw, 50 заданий, экзамен, повтор ошибок и экспорт результатов.
- [Общий каталог LAB-03](docs/lab03/README.md) — последовательность этапов и границы доказательств.

**Данные приборов не следует смешивать с симуляцией:** FETCH — принятая шинная выборка, LED_WRITE — принятая запись MMIO. Вывод о retirement или оптическом состоянии LED из этих событий не следует.
