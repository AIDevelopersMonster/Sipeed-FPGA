# Primer 25K — quick bring-up to full system

## Practical order (agreed)

| Step | Action | Visible result |
| --- | --- | --- |
| 1 | Quick PMOD check: connector mapping, GPIO output/input if modules available | Working port and simple feedback |
| 2 | DVI PMOD: video timing and test pattern | Picture on monitor |
| 3 | TF/microSD: SPI init and CMD17 block read | 512-byte sector over UART |
| 4 | Dock USB-A: inspect host implementation and try HID keyboard | Key events over UART/on display |
| 5 | Integrate basic controllers: UART, SPI, timers, GPIO, video, USB host | Repeatable peripheral test menu |
| 6 | Run processor cores: PicoRV32 / VexRiscv / other suitable HDL cores | Code execution and device access |
| 7 | Firmware / monitors / RTOS and feasible operating systems | Boot, shell, file and device operations |
| 8 | Interactive applications and games | System-level demonstration |

No long research programme is a prerequisite for stage 1. Use available vendor reference designs first; build custom RTL only where needed.

USB-A host support is not proven merely by the presence of the physical connector; use known-good host RTL and verify signals and enumeration. Operating system choice depends on CPU, memory and storage; Linux is not assumed.

## Ground rules
- Program FPGA SRAM first, preserve factory Flash.
- One short log and a reproducible artifact per working stage.
- Avoid unverified pin mappings and unsupported hardware-status claims.
- No external SDRAM assumed installed.
- Keep earlier PR25 processor work as an independent branch of the programme, not as a prerequisite for DVI/TF/USB checks.

**Status: PLAN. No Primer 25K BOARD PASS reported here.**
