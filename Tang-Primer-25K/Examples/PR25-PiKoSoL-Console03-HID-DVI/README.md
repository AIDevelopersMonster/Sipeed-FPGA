# PiKoSoL Console03 — USB HID to BRAM terminal to HDMI/DVI

**STATUS: DEVELOPMENT CANDIDATE; BUILD UNKNOWN; BOARD UNKNOWN. NOT A RELEASE.**
This is a new **console application** using the BOARD-PASS Console02 / Tetris FIX2 USB HID + DVI hardware path unmodified.

## What is implemented in RTL
- 80 x 30 8-bit character VRAM (2400 bytes), with a single synchronous video read and a single prioritized write source. Gowin block-RAM inference requested via attribute; **actual BSRAM use must be checked in the synthesis report**.
- Physical row ring: scrolling advances the top row and clears only the reused 80-character row; no 2400-byte copy and no full-screen reset of flip-flops.
- First boot clears RAM serially, then prints an identification line and `PIKOSOL>` prompt.
- USB HID keyboard: US uppercase A-Z, digits, space, minus, slash, Enter, Backspace; hold repeat; Up restores the previous entered command.
- Commands: `HELP`, `INFO`, `CLS`, `MEM`, `STATUS` (the latter displays constant interface facts, not a readback of live hardware). Unknown commands return a message.
- No UART, CPU, SDRAM, filesystem, or live LED control. Do not claim LED works.

## Hardware unchanged
Tang Primer 25K with Dock, same PMOD DVI connector and USB-A keyboard wiring as verified Console02. S1 enables USB HOST; F1 enters HID diagnostic screen. USB D+ L6 and D- K6; same DVI IP and PLL as the proven Tetris FIX2. FPGA startup PASSIVE by design.

## Build, review and SRAM-only program
Clone the **development branch**; open PowerShell 7 in this folder:

```powershell
.\Build_PiKoSoL_Console03.ps1
```

Requires Gowin 1.9.9 Beta-4 Education, Git, network to retrieve pinned upstream DVI/HID sources. The build invokes Gowin, produces `%TEMP%\PR25_PIKOSOL_CONSOLE_03\impl\pnr\pr25_pikosol_console03.fs` only if successful, and does not program Flash. Inspect `impl\pnr\*.rpt.txt` for `BSRAM` and timing. **This is new RTL and has not yet been built here.**

Only after a successful Gowin BUILD PASS, test the FPGA using the same board hookups:

```powershell
.\Build_PiKoSoL_Console03.ps1 -ProgramSRAM
```

That command rebuilds and **programs only volatile SRAM** (`--run 2`). Do not save an untested `.fs` as a working release.

## Board acceptance
1. DVI shows `PIKOSOL 25K / CONSOLE03 / USB HID`, then `PIKOSOL>`.
2. S1 enters HOST; USB keyboard `HELP` + Enter prints commands.
3. `INFO`, `MEM`, `STATUS` return appropriate information.
4. Type a wrong command; `UNKNOWN COMMAND` appears.
5. Type `HELP`, use Backspace to correct characters, Enter, then Up recalls the last command.
6. Execute at least 35 commands and confirm old rows scroll off the top with no corruption, then `CLS`.
7. F1 still selects the proven USB HID diagnostic screen.

Only after these tests and a video should Console03 be promoted as a working example to `main`.

## Provenance
Derived from Console02 on GitHub; the original Tetris FIX2 USB HID host and PMOD DVI pipeline are retained. Dependency revisions are pinned by the unchanged build architecture. No files from failed Console01 or PR25-07 TERM-DVI have been used as the hardware basis.
