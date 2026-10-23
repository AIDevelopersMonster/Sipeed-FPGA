# LAB-04 — PiKoSoL / Tang Nano 9K / PicoRV32 + HDMI

**Current milestone: LAB-04.3.2 — PiKoSoL Interactive Shell v0.2.0 (23 October 2026): HARDWARE VERIFIED.**

The earlier LAB-04 documentation was written before hardware testing and still contains `PENDING` language. The test results below supersede those old status statements. PiKoSoL is an experimental interactive command environment, not a full operating system.

## Working features

- Actual PicoRV32 RV32I processor in GW1NR-9C, 16 KiB synchronous boot ROM and 1 KiB RAM.
- On-board USB-UART at 115200 8N1: interactive `PiKoSoL>` ASCII commands, Backspace and Ctrl-P single-command history.
- Commands: `HELP`, `INFO`, `MEM`, `STATUS`, `LED 0..6`, `LED ?`, `GFX`, `TERM`, `CLS`, `OBJ A/B`, `MOVE I/J/K/L`, `COLOR R/G/U/W`, `SIZE +/-`, `PANEL`, `KEYS`.
- HDMI 640x480: TERM with 32x76 character video ring; GFX with two bounded objects, a status panel and a six-LED HUD.
- `GFX`, `KEYS`, `jjjkkk` without Enter, `T` to return to TERM.

## Validated gates (23 October 2026)

| Gate | Result |
| --- | --- |
| Sources | `LAB04_SOURCE_INTEGRITY_PASS`, 70 files, ROM 2596/4096 words |
| Model and Icarus RTL (including real PicoRV32) | `LAB0432_RTL_ACCEPTANCE_PASS` |
| Gowin PnR + bitstream | Both completed successfully |
| Physical CDC routes | Graphics index 4/4, value 24/24; TTY 8/8, req/ack both routed |
| STA constraints | 15/15; setup +5.148 ns, hold +0.359 ns, recovery +0.541 ns, removal +1.535 ns |
| STA acceptance | `LAB04_V018B_STA_GATE_PASS` |
| Board | UART command execution, LED MMIO, HDMI TERM/GFX, object movement and live keys tested by the operator and photographed |

**Hardware-tested bitstream** (volatile SRAM only):

- Generated file: `picorv32_lab04_hdmi_nano9k.fs`
- Gowin build: `cpu_20261023_055653_305_52f892`
- SHA-256: `6862C034715DBF557C93C8F8AF8D8AA856CA8F4E62997660CEA9740F3EFDA356`
- Board: Sipeed Tang Nano 9K / GW1NR-9C. Gowin Programmer operation index **2** is SRAM-only.

Синтезированные рабочие файлы исключены из исходных RTL-каталогов. Исключение — явная копия проверенного релизного `.fs` в `docs/lab04/web-loader/firmware/` для работы GitHub Pages. Любая новая сборка требует собственной проверки STA и аппаратной приёмки.

## Source and test references

- [v0.2.0 RU technical guide](../../01-PicoRV32/lab04/README_v0200_LAB0432_RU.md) and [EN technical guide](../../01-PicoRV32/lab04/README_v0200_LAB0432_EN.md) (original pre-acceptance design packages; their `PENDING` statements predate the above physical tests).
- [Firmware](../../01-PicoRV32/lab04/firmware/lab04_boot.S) and [PicoRV32 + HDMI top](../../01-PicoRV32/lab04/rtl/lab04_cpu_hdmi_top.v).
- [SHA-256 source manifest](../../01-PicoRV32/lab04/SHA256SUMS.txt), [source verifier](../../01-PicoRV32/lab04/tools/verify_kit.py), [RTL test driver](../../01-PicoRV32/lab04/tools/test_lab04.ps1), [Gowin build](../../01-PicoRV32/lab04/tools/build_lab04.ps1), [STA checker](../../01-PicoRV32/lab04/tools/check_sta_v018b.py), [board acceptance](../../01-PicoRV32/lab04/tools/test_lab0432_board.ps1).
- [Pinned Sipeed TMDS / HDMI reference](https://github.com/sipeed/TangNano-9K-example/tree/c3b795799f23de91982be52db4273a8eea100cdb/picotiny).

## LAB-04.4 — GitHub Pages WebUSB + Web Serial: hardware PASS (operator-verified)

[**Полный протокол аппаратной приёмки LAB-04.4 (RU)**](LAB044_ACCEPTANCE_2026-10-23_RU.md) · [PiKoSoL WebUSB Loader](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/) · [Web Control Center](https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-control/).

- Подтверждено пользователем 23 октября 2026 года на CHUWI N100 / Windows 11: программирование SRAM со своей GitHub Pages, настоящий UART/Web Serial, светодиоды и HDMI.
- Кнопка автоматической загрузки `.fs` с той же GitHub Pages также подтверждена после устранения междоменного запроса.
- WebUSB: FT2232 Interface A (WinUSB); Web Serial: Interface B (FTDI COM-порт), 115200 8N1.
- Движок `@yowasp/openfpgaloader@1.1.1-182.269` и эталонный `.fs` размещены рядом с веб-страницей; прошивка проверяется по SHA-256.
- Это операторские аппаратные испытания одной установки, а не универсальная сертификация всех ОС, плат и браузеров.

## Scope and known limitations

- No filesystem, processes, preemptive scheduling, networking, USB-host keyboard or complete OS semantics.
- ASCII font only; input line length 47 characters; one-entry history.
- The HDL video banner still prints `v0.1.8b` (legacy static display). The PicoRV32 firmware is v0.2.0. Correct the banner in a later release.

**All physical board claims here refer to the single SHA-256-pinned image above.**
