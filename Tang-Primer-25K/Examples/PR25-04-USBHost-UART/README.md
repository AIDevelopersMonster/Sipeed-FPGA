# PR25-04 USBH01: USB keyboard -> UART terminal (no SDRAM)

**Status (2026-11-14):** CLI bitstream BUILD PASS; SRAM programming was attempted (operator reports UART text after loading FPGA), but an explicit programmer exit report was not supplied; UART text was garbled, COM24/COM25 were not yet confirmed as functional. USB enumeration / HID unverified. Historical milestones below remain preserved.

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

## BUILD FAIL / correction (2026-11-14)

The operator ran the original Gowin CLI `Build_USBH01.ps1` with Gowin `V1.9.9Beta-4_Education` and obtained `can't find device: GW5A-LV25MG121NES`, `GOWIN EXIT: 1`, in `USBH01_BUILD_20261114_124309.log`. No synthesis, no bitstream and no hardware writes occurred. This was a **wrong device part selection in our build script**, not a USB IP failure. Official Sipeed UART demo is `GW5A-25A` with part `GW5A-LV25MG121NC1/I0` and project device id `gw5a25a-002`. Corrected the standalone CLI Tcl command to `set_device -name GW5A-25A GW5A-LV25MG121NC1/I0` (syntax in older Gowin Tcl manual) and aligned `.gprj` accordingly. Re-download **Build_USBH01.ps1** and retry; no rerun of Prepare is required for CLI. If another failure occurs, preserve exact log and update based on evidence. Build remains unverified.

## 2026-11-14: synthesis PASS, placement FAIL (E2 dedicated)

Observed on Windows/Gowin V1.9.9Beta-4 Education, log `USBH01_BUILD_20261114_125520.log`:

- Device `GW5A-25A GW5A-LV25MG121NC1/I0` recognized.
- RTL parser/synthesis all completed, `impl/gwsynthesis/usb_keyboard_uart.vg` and synthesis report generated.
- PNR failed: `PR2028 constrained location useless`, `PR2017 clk_50m cannot be placed at E2: dedicated pin (CPU/SSPI)`.
- No bitstream; no hardware test. `EX3791` size warnings and `m_alu_b` swept warning are separate from placement failure and have not yet been adjudicated.

The build Tcl now explicitly emits `set_option -use_cpu_as_gpio 1` to make dedicated CPU/SSPI pin E2 available for the input oscillator, based on vendor Gowin option and independent Primer25K build patterns. **Correction not yet tested on operator's installation; verify from next PNR log.** No RTL changed; do not write FPGA Flash.

## 2026-11-14: USBH01 CLI bitstream BUILD PASS

Operator's subsequent Gowin CLI build produced **EXIT 0** after resolving reserved E2 CPU/SSPI pin by `set_option -use_cpu_as_gpio 1`:

```text
GOWIN EXIT: 0
USBH01 BITSTREAM FOUND
FILE: C:\GitHub\TangPrimer25K_USBHost_UART\impl\pnr\usb_keyboard_uart.fs
BYTES: 6389757
SHA256: 6DDBBBEF60EF65789687F9A9B5AF710F23899F0F5996DC1AA1B8DDDAD2A52036
STATUS: CLI BUILD FILE PASS; TIMING AND BOARD NOT YET VERIFIED
```

**Evidence classification:** build file PASS; independent STA/timing review NOT yet completed; **SRAM programming NOT YET performed; UART/USB hardware NOT YET tested**. No Flash writes. The generated bitstream is *not* stored in the repo. Next: verify local bitstream SHA-256, program *SRAM only* via `programmer_cli.exe --device GW5A-25A --run 2 --fsFile <path> --cable-index 1`, identify the board's actual debugger COM port, inspect UART at 115200 8N1, and connect a directly wired boot keyboard to Dock USB-A (external hub test follows after direct attach). The UART debug banner should start with `start` but this is an expectation based on upstream source, not yet observed on this board.

## 2026-11-14: serial garbling on BL616 debugger

Operator reported `▒` replacement/garbage characters in COM terminal after loading FPGA; no meaningful responses at COM24 or COM25. Do not infer USB/CPU failure until debugger UART is isolated. Primary candidate: **old BL616 onboard debugger baudrate divisor bug**, explicitly described by Sipeed in [Primer25K FAQ](https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html) and in [issue #14](https://github.com/sipeed/TangPrimer-25K-example/issues/14). Measurements reported on affected firmware: host set 115200 → line ~28826; host set 460800 → line ~115562. Our independent FPGA UART clock is about 48 MHz and its `BAUDCNT 416` targets ~115385 baud; **try opening the BL616 converter-B virtual COM at host setting 460800 8N1, no flow control**. On corrected debugger firmware, normal 115200 should work instead. Do not change both UART divider and host rate at once.

COM24/COM25 must be mapped to the actual BL616 virtual serial channel: [Sipeed serial FAQ](https://wiki.sipeed.com/hardware/en/tang/common-doc/questions.html) identifies **USB Converter B / Load VCP** as serial in the FTDI-compatible interface; infer port association from Windows PnP details, not numeric order. This firmware outputs boot/enumeration/HID diagnostics; it is **not a command shell**, so lack of echo for typed terminal commands is not a failure. Open capture before a fresh SRAM program for one-time boot banner, or connect/disconnect USB-A keyboard after opening COM to create enumeration messages; never reboot by unplugging USB-C after SRAM programming because SRAM is volatile.

Only if baud adjustment fails: isolate the UART using a separate, periodically transmitting FPGA-only UART diagnostic (no USB/RV32I), then consider Sipeed's **official BL616 debugger firmware update guide** after checking existing debugger firmware revision: [Update debugger](https://en.wiki.sipeed.com/hardware/en/tang/common-doc/update_debugger). Updating debugger firmware is a distinct, risk-bearing process and must not be conflated with SRAM-only FPGA programming. The already verified C3=FPGA TX / B3=FPGA RX pinout is **correct** according to the board schematic and issue #14.
