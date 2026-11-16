# PiKoSoL Console02 — Tang Primer 25K USB HID + HDMI/DVI

**Status: Gowin BUILD PASS; BOARD PASS for demonstrated functions (2026-11-16).**
**Video:** https://youtube.com/shorts/cl_KkzxRx30

PiKoSoL command monitor on Sipeed Tang Primer 25K + Dock, no CPU, no UART, no external SDRAM. The **hardware I/O path** is derived from the physically tested `PR25-TETRIS-HID-06-FIX2` project, preserving its USB HID host, Gowin DVI_TX wrapper, PLL, PMOD mapping, electrical constraints, and S1/F1 mode switching. Only application/game logic was replaced.

## Verified evidence

- Operator Gowin log (2026-11-16 04:37:55): synthesis, place/route and bitstream generation completed; output `pr25_pikosol_console02.fs`, **6,013,969 bytes**.
- SHA256 of locally built bitstream: `8E79A763F17D24BB31700A20459CB26ECB11007513C994A95D26C314AD5A88E0`.
- Hardware photographs show (1) console title and `PIKOSOL>` prompt, with `HELP: HELP INFO CLS` response (the response is selected by the `HELP` command decoder), (2) USB HID diagnostics, and (3) passive USB-line diagnostics.
- Video: https://youtube.com/shorts/cl_KkzxRx30.
- **Not separately verified:** `INFO`, `CLS`, backspace/line editing, sustained operation, all USB keyboards, timing slack/STA margins. Do not expand BOARD PASS to these cases without tests.

## What the demo implements

- Standard USB-A keyboard through the FPGA USB HID host. **S1** switches PASSIVE/HOST; **F1** switches console/HID diagnostics.
- Gowin DVI_TX through the PMOD DVI adapter; 640×480 image.
- 8×16 text cells rendered from an on-chip 5×7 font. No external video framebuffer or SDRAM.
- 16-character, uppercase-US command buffer with `HELP`, `INFO`, `CLS`; Enter and Backspace logic included.
- FPGA RTL only: no RISC-V CPU, no UART, no filesystem, no USB hub.

## Source tree

- `lab_top_pikosol_console02.sv` — **derived from tested Tetris FIX2 top**, including USB HID and video/diagnostics.
- `pikosol_console_core.sv` — command parser and display.
- `Build_PiKoSoL_Console02.ps1` — rebuilds pinned HDMI/DVI and USB dependencies, then runs Gowin.
- `Program_SRAM.ps1` — programs only FPGA SRAM from an exact-hash checked prebuilt image by default, or the local generated image with `-Built`.
- `firmware/pr25_pikosol_console02.fs` — expected location of operator-verified firmware when its binary is uploaded; **do not treat this README as proof of upload**.

## Hardware connections

- **Board:** Tang Primer 25K + Dock, GW5A-25A.
- **Video:** Sipeed PMOD DVI connected exactly as in the demonstrated `PR25-TETRIS-HID-06-FIX2` arrangement; do **not** move connector or reassign pins.
- **Keyboard:** USB-A connector on the board; USB D+ = FPGA L6 (GPIO[30]), D− = K6 (GPIO[31]).
- **S1:** activate USB HOST from startup PASSIVE. **F1:** toggle console / original HID diagnostics.
- **UART:** not required or enabled. Future USB-C/BL616 or external GPIO UART experiments are **not** part of this version.

## Build on Windows PowerShell 7

Requirements: Gowin V1.9.9Beta-4 Education (default script paths below), Gowin Programmer CLI, Git and network for immutable pinned dependencies.

Open PowerShell inside the project folder:

```powershell
.\Build_PiKoSoL_Console02.ps1
```

The exact source files on GitHub are the input. Dependency revisions are pinned in the script. Build output appears at:

```text
%TEMP%\PR25_PIKOSOL_CONSOLE_02\impl\pnr\pr25_pikosol_console02.fs
```

Build does not touch the board. On success the script reports output size and SHA256. Successful generation of a file **is not** proof of timing closure: review `impl/pnr/*.rpt.txt` and timing reports separately.

## Program FPGA — volatile SRAM only

**Option A: prebuilt verified file**, if `firmware/pr25_pikosol_console02.fs` is present in the project folder. It must have the SHA256 above:

```powershell
.\Program_SRAM.ps1
```

**Option B: firmware you just compiled**:

```powershell
.\Program_SRAM.ps1 -Built
```

Or rebuild and program in one operation:

```powershell
.\Build_PiKoSoL_Console02.ps1 -ProgramSRAM
```

All commands use the SRAM programming operation (`--run 2`); **configuration Flash is never written**. On the board, press S1 to activate HOST, then test `HELP` + Enter and F1 to switch HID diagnostics. Avoid connecting USB devices to unverified pin arrangements.

## Dependencies and provenance

- `PR25-TETRIS-HID-06-FIX2`: source and fully demonstrated USB/DVI baseline.
- USB HID host `m1nl/usb_hid_host` (Apache-2.0), commit `5d2bf72472bddc6da71134fa7d29d42a99a02f0a`.
- USB PLL source `nand2mario/usb_hid_host`, commit `678b0137bd32d1ca99fb2d48865f4eb1df712c4e`, locally modified in generated copy for 60 MHz.
- DVI wrapper from `yuri-panchul/basics-graphics-music`, commit `817bd4dac8ab45d5c22bdd78b441bedb80672cd0`. Gowin generated IP and vendor toolchain constraints still apply.

**Publication discipline:** board pass refers only to demonstrated functions; no new release and no unrelated files. An exact-hash verified `.fs` belongs in this project folder before promoting it as a completely reproducible example.
