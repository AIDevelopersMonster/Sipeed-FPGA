# EX20-06 FONT v0.4 — operator build and timing evidence (2026-11-14)

**Source commit of user-built candidate:** `5cff023e38298213fae7478f0df4b6919e7d6ae2`. Operator PowerShell output, candidate `candidate_20261114_070316_093`. This source includes the updated PicoRV32 ROM FONT 1/2 protocol and 1x/2x HDMI renderer; no FPGA programming performed in the reported build.

## Results

- Python contracts: **13/13 PASS**
- Renderer Icarus `PIKOSOL20K_RENDERER_PIPELINE_SIM_PASS`; reset Icarus `PIKOSOL20K_RESET_SIM_PASS`
- ROM generator `LAB04_ROM_BUILD_PASS`: **2883 instructions**, SHA256 **7BE4C7E6F1ED5297A6059274B21AE295187BD48B41BDDD8BC558D29F3B82575D**
- Gowin generated .fs: **7,264,150 bytes**; SHA256 **DD75E28DAE5F4D3CF8B2C4BCDABEF7849303A9C029D71117EBAC252F2012DCBC**
- Pixel `pix_clk` Fmax **102.136 MHz**, versus required 74.25 MHz
- First listed Setup Slack **+0.476 ns**, Hold **+0.227 ns**, Recovery **+12.116 ns**, Removal **+0.925 ns**
- Global setup/hold violated endpoints **0/0**; all 6 CPU/pixel/high-speed per-clock setup+hold TNS rows 0.000; all six specific CDC first-stage exceptions active
- `STA_GATE_EXIT=0`, `PASS_FOR_IO_REVIEW_NOT_BOARD`.
- **PR1014 clock feeder routing warning remains**. Source and hardware risk review already documented for STA-5; the new candidate still requires its own pin report inspection.

## Experimental pilot guard

For FONT v0.4, `tools/sram_pilot_font.ps1` is pinned to candidate `candidate_20261114_070316_093`, the above SHA256, .fs length, passing `STA_GATE.json`, RESET pin 88 / LVCMOS33 / 3.3 V fitted pin report, and `clk27_d/pix_clk/serial_clk` PnR global-clock placements.

- Running without switches is a **preflight-only JTAG scan**; it never programs FPGA.
- `-Program` is an explicit opt-in SRAM-only `programmer_cli.exe --run 2` action, guarded by human confirmation after observing one matching `GW2AR-18C` with JTAG ID `0x0000081B`.
- Existing `tools/sram_pilot.ps1` remains pinned to the **previous hardware-working STA-5** SHA256 `1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2`. Do not change or overwrite it.

## First hardware experiment

1. Fetch and detach latest feature branch while preserving prior build artifact folders; close MobaXterm/other JTAG clients.
2. Preflight `.\tools\sram_pilot_font.ps1` and inspect the detected JTAG device and board.
3. Only after preflight: opt-in `.\tools\sram_pilot_font.ps1 -Program`. Never write Flash.
4. COM25 at 115200 8N1: check PiKoSoL boot text, `HELP`, corrected `INFO`, `FONT 1` and `FONT 2`; verify 160x60 vs 80x30 text on the HDMI display and no clipping, GFX and LEDs independently. The reset of VRAM on each font switch can cause very early echoed characters to be temporarily discarded; send `HELP` after waiting for the terminal output to stabilize.
5. Power-cycle, confirm factory Flash image returns; record objective board results and do not label full BOARD PASS until new font geometry and switching are witnessed.

**Claim discipline:** the operator-provided console validates Icarus and Gowin PnR/STA, *not* physical HDMI font rendering. No claim of new BOARD PASS is made.
