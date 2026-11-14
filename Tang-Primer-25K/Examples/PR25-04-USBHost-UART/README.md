# PR25-04 USBH01: USB keyboard -> UART terminal (no SDRAM)

**Status:** sources prepared in GitHub; no bitstream built; no hardware test yet.

Goal: connect a *wired USB boot-HID keyboard* to Tang Primer 25K Dock USB-A (USB host), read enumeration and HID events in a Windows terminal via the board's USB-C debugger COM. No HDMI, DVI, external SDRAM, microSD, or extra PMOD.

## Implementation

Reuse the published USB 1.1 host, USB PHY/SIE, RV32I and precompiled host firmware from [thisiseth/tang-primer-25k-spi-io](https://github.com/thisiseth/tang-primer-25k-spi-io/tree/cce99075f06d0946c8a70c221118df2c4b57fe2a/src/fpga/spi_io_bridge) (commit `cce99075f06d0946c8a70c221118df2c4b57fe2a`). This in turn uses the [emard USB host](https://github.com/emard/usb_host) implementation. The existing RV32I memory lives in BRAM, initialized by `ucmem/mem.hex`. We do not modify USB firmware or its algorithm; our minimal top-level connects its outputs to the Dock. Original debug UART runs at 1 Mbaud; the prepare script changes only `BAUDCNT` from 48 to 416, yielding about 115.4 kbaud.

## Wiring and constraints

| Feature | GW5A pin | Source |
|---|---|---|
| 50 MHz oscillator | E2 | Sipeed board pinout |
| USB-A host D+ | L6 | thisiseth `pins.cst` |
| USB-A host D- | K6 | thisiseth `pins.cst` |
| UART TX -> USB-C onboard debugger | C3 | Sipeed `UART/simple_uart/src/top.cst` |
| UART RX <- USB-C onboard debugger | B3 | Sipeed `UART/simple_uart/src/top.cst` |

Do not confuse the board's **USB-A host** with the board's **USB-C programming/serial connection**. Attach/remove keyboard or USB modules with power off, especially while diagnosing.

## PowerShell preparation

```powershell
$prepare = 'C:\GitHub\Prepare_USBH01.ps1'
$url = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-04-USBHost-UART/Prepare_USBH01.ps1'
Invoke-WebRequest -Uri $url -OutFile $prepare
& $prepare
```

Script downloads four GitHub project files and seven original vendor source assets at a **pinned upstream commit**, creates `C:\GitHub\TangPrimer25K_USBHost_UART\usb_keyboard_uart.gprj`, and copies firmware init into the project root. The script does not run Gowin, access USB devices or program FPGA.

## Build (manual Gowin IDE, same verified installed environment)

Open `C:\GitHub\TangPrimer25K_USBHost_UART\usb_keyboard_uart.gprj` via **File -> Open Project**. Check device `GW5A-25A`, top `top`; run **Run All**. We are not assuming the old Gowin Tcl `open_project` / `create_project` commands work on the installed edition.

First verify built `C:\GitHub\TangPrimer25K_USBHost_UART\impl\pnr\usb_keyboard_uart.fs` and inspect the actual synthesis/PNR reports. If Gowin cannot locate the RISC-V `ucmem/mem.hex`, confirm the project working directory and init path. **No build PASS until `.fs` exists.**

After successful synthesis, upload **only SRAM** with the already demonstrated `programmer_cli.exe` operation `--run 2`. Do not touch Flash. Use the board debugger COM port at **115200 8N1, no flow control**, not an arbitrary COM number.

Expected serial evidence, based on unmodified upstream firmware:

```text
start ...
device connect, speed = ...
SET ADDR ok
GET TASK DESC ok
GET CONF DESC ok, size = ...
SET CONFIG ok
std keyboard detected (...)
KEYBD: 0 0 4 0 0 0 0 0
```

The keycodes are **USB HID report bytes in hex**, not ASCII. First goal is basic keyboard enumeration and changing HID codes. ASCII mapping can be an independent follow-up lab.

## Evidence stages

1. PREPARE PASS: source files created on PC.
2. BUILD PASS: proper `.fs`, timing report.
3. SRAM PROGRAM PASS: programmer 100%, exit 0.
4. UART PASS: RISC-V boot/USB messages at 115200.
5. USB ENUM PASS: `std keyboard detected`.
6. HID PASS: codes change on pressing keys.

Known limits: boot-protocol keyboards first; some composite, wireless and NKRO keyboards need additional testing. A lack of UART text might be a clock/UART/BRAM-init problem, not yet a USB problem. Original cores remain attributed to their upstream authors.

## Reserve option: microSD over SPI

A simple SPI-mode microSD reader is a viable follow-on using a physical microSD/TF PMOD and a small FPGA controller (no external SDRAM). Track separately under `Tang-Primer-25K/PMOD/TF` after the USB-UART test.

## User test evidence — source preparation

On 2026-11-14 the operator executed `Prepare_USBH01.ps1` on Windows PowerShell and reported:

```text
USBH01 PREPARE: PASS
UPSTREAM REV: cce99075f06d0946c8a70c221118df2c4b57fe2a
PROJECT: C:\GitHub\TangPrimer25K_USBHost_UART\usb_keyboard_uart.gprj
UART: 115200 8N1
BUILD: NOT RUN; BOARD: NOT TESTED
```

**Verdict:** Source preparation confirmed. Synthesis, timing, bitstream generation, SRAM programming, UART link and USB keyboard enumeration remain untested. Next required evidence: Gowin IDE Run All output and .fs file and synthesis/PNR logs from *USBH01 project*.

## Automated CLI build (preferred)

User preference: **PowerShell/Gowin CLI for routine builds and SRAM programming**. Reserve Gowin IDE GUI for actual educational/engineering inspection of synthesized logic, memory, clock networks, floorplanning, timing and physical routing—not merely pressing Run All to obtain a bitstream.

The new [`Build_USBH01.ps1`](./Build_USBH01.ps1) produces a deterministic local Tcl using `set_device`, `set_option`, `add_file`, `run all` and invokes the installed `gw_sh.exe` in the project working directory, capturing `evidence/USBH01_BUILD_*.log`. This is **not yet tested on the operator's local Gowin installation**. Failure should be investigated from the log, not treated as board failure. No Flash writes or SRAM programming are performed.

```powershell
$build = 'C:\GitHub\Build_USBH01.ps1'
Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-04-USBHost-UART/Build_USBH01.ps1' -OutFile $build
& $build
```

After an actual successful build, select a meaningful component (e.g. UART divider/shift register, USB SIE finite-state machine, RV32I and BRAM) and use Gowin GUI to inspect and compare the RTL/synthesis/physical implementations and constraints.

## Build script verified command syntax (2026-11-14)

Updated `Build_USBH01.ps1` to the documented Gowin CLI form `set_device GW5A-LV25MG121NES` and removed the unverified `-use_cpu_as_gpio` option. `-verilog_std sysv2017`, `run all` and `gw_sh.exe script.tcl` align with Gowin documentation. **The local Gowin V1.9.9Beta-4 Education build remains NOT RUN / NOT VERIFIED**; operator must run the new script and provide terminal output.

The Tang Primer 25K Dock has a **USB-A host port**, not an integrated USB hub. First validate a wired boot-protocol HID keyboard *directly* in USB-A, then use an external USB 1.1/2.0 hub as a second independent test if desired. Third-party host firmware includes hub support, but that support has not been validated on this particular hardware sample.
