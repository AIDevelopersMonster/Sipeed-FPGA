# PiKoSoL Console02 — Tang Primer 25K USB HID + DVI

**Development branch / RTL candidate — BUILD UNKNOWN, BOARD UNKNOWN. NO RELEASE.**
This is NOT based on the unverified UART and TERM-DVI examples. Hardware I/O comes from the demonstrated Tetris FIX2 project: USB HID host, pinout, DVI PMOD, Gowin DVI_TX, PLL, and S1/F1 logic. Only the application module changes.

## What is present

- One 640x480 HDMI/DVI text screen. A small on-chip 5x7 font, rendered into 8x16 character cells, avoids the previous failed 2400-byte multidriver VRAM.
- USB keyboard in HOST mode: uppercase A-Z, digits, space, Backspace, Enter. Commands `HELP`, `INFO`, `CLS`; max command length 16.
- **S1** activates USB HOST from PASSIVE; **F1** switches CONSOLE/HID DIAG. Physical wiring and USB pins from Tetris FIX2 are kept.
- At startup expected screen: `PIKOSOL 25K - USB CONSOLE`, a command guide, and `PIKOSOL> `.
- Limitations: US keyboard map; no cursor or scrolling; `CLS` clears static guidance and response, not the prompt; built-in command buffer uses registers; no CPU, UART, filesystem or SDRAM yet.

## Windows / PowerShell 7 build

Requirements: Gowin Education 1.9.9 Beta-4 at the configured path, git, network access to pinned dependency revisions. You can override Gowin paths via parameters. From this source folder:

```powershell
.\Build_PiKoSoL_Console02.ps1
```

The build script derives the **same vendor DVI project, USB HID host and PLL** from immutable upstream commits as the tested Tetris build. It writes to `%TEMP%\PR25_PIKOSOL_CONSOLE_02\`, leaves the connected FPGA and Flash untouched, and prints an FS path only if Gowin succeeds. **No .fs is supplied because no Console02 bitstream has been tested on the board.**

After a successful compilation, and only with the DVI PMOD and USB keyboard already connected as in the Tetris FIX2 demo:

```powershell
.\Build_PiKoSoL_Console02.ps1 -ProgramSRAM
```

This recompiles and then programs volatile SRAM only; does not modify Flash. Confirm S1 => host, then type HELP / INFO / CLS; use F1 to compare the preserved HID diagnostic screen. Record Gowin build log, actual image and keyboard reactions before labeling PASS.

## Reuse and safety

- Derived from `PR25-TETRIS-HID-06-FIX2/source/lab_top_tetris_hid06.sv` and `Build_Tetris_HID06.ps1`.
- Keyboard, DVI/HDMI, USB pin mapping, PLL, external dependencies and F1 diagnostics deliberately retained.
- This candidate has NOT undergone actual Gowin synthesis, STA, board test or video demonstration.
- **UART deferred**. Later study USB-C/BL616 electrical routing vs direct FPGA GPIO/UART pins separately. No unverified wiring claims.
