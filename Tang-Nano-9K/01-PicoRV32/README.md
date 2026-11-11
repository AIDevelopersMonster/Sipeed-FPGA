# 01 — PicoRV32 / Tang Nano 9K

**Актуальный статус на 23.10.2026:** [PiKoSoL LAB-04.3.2](../docs/lab04/README.md) — аппаратно проверенный CPU+HDMI; [LAB-04.4](../docs/lab04/LAB044_ACCEPTANCE_2026-10-23_RU.md) — браузерный WebUSB SRAM-программатор и Web Serial-управление (операторский аппаратный PASS). Ниже сохранён исторический протокол LAB-02.


## Current lab — LAB-02 USB-UART / HTML-linked LED control (20 October 2026)

**Verified:** MODEL_PASS, RTL_PASS, PNR_PASS, STA_PASS, BOARD_PASS, HTML_HARDWARE_PASS. The physical FPGA receives commands `0`–`6` and `?` over its onboard USB UART, controls L1–L6 via MMIO and replies `L=n`. Web Serial linked HTML maps its conceptual step 14 to an acknowledged hardware LED change, including reversible 13 → 14 → 13 → 14 behavior. Manual, automatic and three-LED linked tests were reported successful.

**STA:** required 27.000 MHz; achieved Fmax 52.522 MHz; setup/hold TNS 0.000. **ROM:** 118 RV32I instructions / 1 KiB. The educational four-instruction, nineteen-step model is a separate visualization, not a cycle-accurate CPU trace.

[**RU/EN complete lab manuals, PDFs and linked HTML**](../docs/lab02/README.md).

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\tools\test_lab02.ps1 -ModelOnly
& .\01-PicoRV32\tools\test_lab02.ps1
& .\01-PicoRV32\tools\build_gowin.ps1
# Inspect PnR/STA; configure SRAM only. Then, with board connected:
& .\01-PicoRV32\tools\probe_lab02_serial.ps1 -PortName COM10
& .\01-PicoRV32\tools\launch_lab02_html.ps1 -Language RU
```

**Historical P1 note:** the older sections below describe the 19 October 2026 `PICO` demonstration. The LAB-02 branch/HEAD contains a *different* ROM program; those P1-specific `test.ps1` expectations must not be applied to the current LAB-02 firmware. The P1 implementation remains reproducible from the previous Git commit `88f90d65c500fc1e2c71f13c774dc919a4bd3a34`.

---

**Stage v0.1 / BOARD_PASS:** 33-instruction PicoRV32 ROM demo, MMIO LED/counter/UART, RTL simulation, Gowin STA and physical SRAM programming on Tang Nano 9K verified 19 October 2026.

## Interactive LED1 HTML demonstration

[Open the PicoRV32 LED1 interactive demo RU/EN](../docs/interactive/picorv32-led1/README.md) — four instructions, 19 instructional steps, including ROM, GPR, native memory bus, MMIO and physical LED1. This **separate conceptual model** is not a cycle-accurate RTL simulation or the 33-instruction physically tested image.

## Hardware and architecture

- GW1NR-LV9QN88PC6/I5, clk=27 MHz, reset active-low (physical pin 3).
- Core: PicoRV32 configured RV32I, reset PC = `0x00000000`.
- Boot ROM: 1 KiB, no RAM/stack; generated from `firmware/boot.S` by small *subset* assembler.
- `0x20000000` MMIO: LEDs, clock counter, device ID, firmware marker, UART TX and ready.
- On-board UART TX/RX: pins 17/18, 115200 8N1; RX pin is reserved, no receive controller in v0.1.
- LEDs active-low: pins 10,11,13,14,15,16; test uses positive logical state that is inverted at pins.

This first prototype intentionally does not include PSRAM, SPI Flash XIP, interrupts, C runtime, SDRAM, filesystem, or an operating system.

## First executable commands (PowerShell)

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\tools\test.ps1 -PythonOnly
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test.ps1
```

`-PythonOnly` validates the ROM generator and boot code interpreter, but it does **not** verify the RTL. Full `test.ps1` invokes two RTL simulations in Icarus Verilog: independent UART (`tb_uart`) and PicoRV32+MMIO+ROM (`tb_soc`). `iverilog`, `vvp` must be in `PATH`.

To build with installed Gowin Education CLI:

```powershell
& .\01-PicoRV32\tools\build_gowin.ps1
```

Generated `.fs` must be checked against synthesis and timing reports. This P1 reference design was placed, routed and tested on Tang Nano 9K. For **any new build**, still inspect synthesis and timing reports before programming.

For SRAM-only programming, after PnR succeeds:

```powershell
$prog = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
$fs = (Resolve-Path '.\01-PicoRV32\impl\pnr\picorv32_nano9k.fs').Path
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index 1
$LASTEXITCODE   # expected 0 with the validated FT2CH cable
```

Never program onboard configuration flash in the initial experiment. Inspect the COM port with `Get-CimInstance Win32_SerialPort` and use a serial terminal at `115200 8N1` after FPGA programming, keeping the port closed during programming.

## Observable behavior / expected outputs

1. A UART line `PICO` followed by LF after each reset.
2. Firmware writes `0x600DCAFE` to the MMIO completion register.
3. Six LEDs change according to hardware free-running cycle counter (speed can be adjusted by changing `srli t4, t4, 20` in firmware and regenerating ROM).

`PICO` was **observed** from the physical FPGA via COM10 at 115200 baud; the `0x600DCAFE` status-register value was confirmed by the RTL testbench, but it was not separately probed on the physical board. The UART testbench checks outgoing bytes using internal `tx_start`; the separate transmitter testbench checks actual 8N1 bits. Future revisions should add receive, bus stall, long-run and back-to-back-access tests.

## Origin, licensing, reproducibility

CPU is from `https://github.com/YosysHQ/picorv32`, ISC license, pinned commit `ef203c2b0a3fb793280f5114941416c425c5b461`. Fetch script is non-destructive: refuses existing conflicting local checkouts. Official Sipeed reference for PCB constraints: `https://github.com/sipeed/TangNano-9K-example`.

## Files

- `rtl/picorv32_soc.v` — CPU and minimalist bus / MMIO integration.
- `rtl/uart_tx_8n1.v` — standalone 8N1 transmitter.
- `rtl/boot_rom.v` — generated synthesizable ROM module.
- `firmware/boot.S` — transparent RV32I source.
- `firmware/boot.hex` — generated ROM words, used for Python boot-model check.
- `tests/` — standalone UART and CPU/SoC Icarus benches.
- `constraints/` — Tang Nano 9K pin and clock definitions.
- `picorv32_nano9k.gprj`, `gowin_build.tcl` — Gowin CLI compilation project.

## Known gaps / audit before declaring PASS

- Model, RTL (Icarus), Gowin synthesis/PnR/STA and physical SRAM/board tests passed in the Windows laboratory on 19 October 2026; not all ISA instructions have been exhaustively verified.
- The current Gowin project built under the validated Windows Gowin Education 1.9.9 environment; other versions and board revisions remain untested.
- The UART receiver input is deliberately unused.
- This is a boot and MMIO experiment, NOT a representative CPU benchmark.
- Constraints and polarity were exercised on the tested board; different board revisions still require independent pinout/voltage verification.
