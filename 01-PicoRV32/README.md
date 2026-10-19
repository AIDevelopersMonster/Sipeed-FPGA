# 01 — PicoRV32 / Tang Nano 9K

**Stage v0.1: self-contained ROM generation, MMIO LED/timer/UART, and simulator integration. FPGA operation has NOT been established.**

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

Generated `.fs` must be checked against synthesis and timing reports. Stage P1 is experimental; if timing fails or device primitives cannot be inferred, debug before trying to program a physical board.

For SRAM-only programming, after PnR succeeds:

```powershell
& .\01-PicoRV32\tools\program_sram.ps1 -Bitstream 'C:\full\path\to\picorv32_nano9k.fs'
```

Never program onboard configuration flash in the initial experiment. Inspect the COM port with `Get-CimInstance Win32_SerialPort` and use a serial terminal at `115200 8N1` after FPGA programming, keeping the port closed during programming.

## Observable behavior / expected outputs

1. A UART line `PICO` followed by LF after each reset.
2. Firmware writes `0x600DCAFE` to the MMIO completion register.
3. Six LEDs change according to hardware free-running cycle counter (speed can be adjusted by changing `srli t4, t4, 20` in firmware and regenerating ROM).

`PICO` and the status register are **expected**, not yet observed on real hardware. The UART testbench checks outgoing bytes using internal `tx_start`; the separate transmitter testbench checks actual 8N1 bits. Future revisions should add receive, bus stall, long-run and back-to-back-access tests.

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

- Pure model check run by author; **RTL test and PnR not run in author environment** (EDA simulators not available there).
- `.gprj` and HDL pin mapping need testing in the user's installed Gowin IDE version.
- The UART receiver input is deliberately unused.
- This is a boot and MMIO experiment, NOT a representative CPU benchmark.
- Tang Nano 9K voltage banks, switch polarity and default pin states must be checked on actual board revision before programming.
