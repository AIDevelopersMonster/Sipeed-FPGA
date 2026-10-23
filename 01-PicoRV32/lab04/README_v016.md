# PiKoSoL LAB-04.2 v0.1.6 — CPU/MMIO LED -> HDMI HUD (candidate)

**Release status:** candidate source patch based on the user-supplied LAB-04 v0.1.5
source ZIP. It has not been synthesized by Gowin or tested on a physical board.
Do not claim PNR, STA or BOARD PASS for v0.1.6 until tested on Tang Nano 9K.

## What changes

- `lab04_cpu_soc.v` exposes the true, *uninverted*, six-bit LED MMIO register.
  It does not change the LED address (`0x20000000`), firmware or UART ABI.
- `lab04_led_mask_cdc.v` performs an acknowledged, bundled-data transfer from
  clk27 to 25.2 MHz pixel clock. Burst writes may be coalesced, but the **latest**
  state is delivered; no raw six-bit asynchronous sampling for the HUD.
- `lab04_led_osd.v` draws six bars left-to-right (LED1..LED6) along the bottom
  of the 640x480 HDMI image. ON=bright green, OFF=dark gray, white border.
  A new mask is sampled once per frame at the SVO SOF beat.
- SVO **terminal** remains present: host input and CPU replies stay visible.
- PLL, CLKDIV, video clock and reset generation, three OSER10 lane resets,
  physical pin constraints, MMIO, ROM images, SDC and external vendor sources
  have not been modified.

## Verifications provided

`tools/test_lab04.ps1 -ModelOnly` checks original firmware model, static
source contracts, reset and SDC guard, and the new integration contracts.
`tools/test_lab04.ps1` additionally requires `iverilog` and `vvp` to run
UART, CDC mailbox, and pixel-overlay RTL simulations. **These tests must be
run locally; the delivered source candidate itself does not prove RTL PASS.**

The CDC and OSD benches cover back-to-back masks, atomic six-bit updates,
ready/valid stalls, frame snapshot, individual LED fill, inactive LEDs,
borders, and pixel pass-through. They do NOT replace full SoC integration,
P&R/STA, or a live HDMI test.

## Application and build

1. Unzip patch into Downloads, not on top of the repository.
2. Run `Apply-LAB04-v016.ps1 -RepoRoot C:\GitHub\Sipeed-FPGA` without
   `-Apply` first. This checks exact v0.1.5 file hashes and new-file absence.
3. Run the same script with `-Apply`. It backs up changed files under ignored
   `01-PicoRV32\lab04\build\patch_v016_backup_...` and copies only files
   under `01-PicoRV32\lab04`.
4. Run `python .\01-PicoRV32\lab04\tools\verify_kit.py` from repo root,
   then tests and build as below.

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\lab04\tools\test_lab04.ps1 -ModelOnly
& .\01-PicoRV32\lab04\tools\test_lab04.ps1
& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU
```

`build_lab04.ps1` creates an isolated build under `lab04\build\` and **never**
programs FPGA. Inspect the new Gowin timing report *including all new CDC*
paths. `check_sta_v013.py` handles older SVO constraints but is **not**
a complete new CDC audit; check all setup/hold/recovery/removal endpoints,
PLL clocks, path exceptions and constraint matches manually. A successful
model, RTL and bitstream generation alone are not sufficient.

Only after PnR/STA PASS, program candidate `.fs` to **SRAM** using Gowin
Programmer operation index 2, never external Flash (`8/9`). The original
v0.1.5 bitstream can be restored to SRAM if v0.1.6 exhibits regressions.

## Board acceptance

After passing STA, and only after programming the new `.fs` to SRAM, run:

```powershell
& .\01-PicoRV32\lab04\tools\test_lab04_v016_board.ps1 -PortName COM10
```

This automated UART test sends 0, ?, 1, ?, f, ?, 6, ?, 0, ? and checks
`C=n`, `L=6`, `M=XX`. It does not prove HDMI graphics; inspect the monitor
and physical LEDs in parallel. Close other serial terminals beforehand.


UART COM10 115200 8N1: write `1`, `f`, `6`, `0`, `?` and read responses;
confirm physical LEDs and HDMI bottom six-bar OSD match the readback, while
PicoRV32 terminal and HDMI are stable. On `1`, first bar ON; on `f`, last bar
ON; on `6`, all six ON; on `0`, all OFF. Changes appear by the next frame
(after CDC/handshake convergence), not necessarily in the same pixel clock.

**Scope disclaimer:** The FPGA JTAG/HDMI/CPU/UART/LED hardware success from
v0.1.5 is baseline evidence, not evidence that the new overlay passes timing.
