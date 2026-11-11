# KonSol RetroStation — BREAKOUT RGB v0.1.0

**Hardware-tested retro arcade game for Sipeed Tang Nano 9K · 26 October 2026.**

New independent Verilog gameplay: HDMI 640×480, 32 colored bricks, bat and ball, three lives, four visual palettes, winning and losing states. The operator reported completing and **winning the game on a physical Tang Nano 9K** with a local PowerShell USB-UART keyboard.

## Contents

- `pikosol_breakout_rgb_nano9k.fs` — binary for **GW1NR-9C / Tang Nano 9K only**, loads to **volatile FPGA SRAM only**.
- `SHA256SUMS.txt` — fixed hash of operator-tested build.
- HDL source, constraints, PowerShell build, testbench, keyboard, acceptance notes: https://github.com/AIDevelopersMonster/Sipeed-FPGA/tree/main/games/breakout-rgb

Expected firmware SHA-256: `4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789`.

## Quick start

Download the bitstream asset and verify SHA-256. Open https://aidevelopersmonster.github.io/Sipeed-FPGA/lab04/web-loader/ in Chrome/Edge, select **KonSol BREAKOUT RGB**, choose the downloaded local `.fs`, check **SHA256 PASS**, then use **JTAG Debugger** to program Tang Nano 9K **SRAM**. Do not write FPGA Flash.

Windows PowerShell UART game controller:

```powershell
.\games\breakout-rgb\tools\control_breakout.ps1 -PortName COM10
```

Controls: arrows or A/D move, P/Space/Enter launches, R restarts, 1–4 palettes, Q/Esc quits. UART 115200 8N1 via FT2232 channel B.

## Verification boundaries

- Operator SIM SMOKE PASS, Gowin BUILD PASS; 0 setup/hold violations in clock summaries.
- Positive minima among **25 extracted paths/type**: setup +6.035 ns, hold +0.550 ns, recovery +0.232 ns, removal +0.870 ns.
- Resource use: logic 19%, registers 8%, BSRAM 0%.
- **Operator BOARD PASS** with complete victory; no independent board certification.
- A browser WebUSB profile is available for the local file, but its own end-to-end board test has not yet been performed.

Original HDL: MIT, SimpleVOut dependency: ISC, Gowin vendor IP and software under their own license terms. No historical ROMs shipped.

Project: https://github.com/AIDevelopersMonster/KonSol-RetroStation
