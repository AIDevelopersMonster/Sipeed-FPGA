# KonSol RetroStation RS-003 — Breakout RGB (source candidate)

**STATUS: SOURCE CANDIDATE ONLY — NOT SIM PASS, NOT FIT PASS, NOT BOARD PASS, NOT RELEASED.**

Independent Verilog Breakout for Sipeed Tang Nano 9K (GW1NR-9C), using the existing PiKoSoL HDMI SVO and UART infrastructure. Pong remains unchanged.

Features in source: 8x4 bricks, 3 lives, paddle, ball, READY/PLAY/WON/LOST, palette switch, raster-based HDMI 640x480. Does not use PicoRV32 or game ROMs.

UART 115200 8N1: w/W left press/release, s/S right press/release, p or Space launch, r restart, x release keys, 1-4 palettes.

## Build (not executed)

From the Sipeed-FPGA repository on Windows PowerShell 7:

```powershell
.\01-PicoRV32\lab04\tools\fetch_picotiny.ps1
.\games\breakout-rgb\build.ps1
```

Never program an unexamined candidate. Require simulation, Gowin FIT, and exact-build STA (0 setup/hold violations, positive recovery/removal margins) before SRAM-only hardware tests.

## Known gaps

- Initial collision model is intentionally simplified; not yet verified by an HDL simulator.
- No testbench verdict or physical measurements, and no released .fs.
- No independent browser keyboard page yet. Existing Pong Web Serial page is not a complete Breakout UI.
- Game score is internally counted, but a numerical score display has not been implemented.
- Do not include this in the published PiKoSoL WebUSB firmware list until exact-version tests pass.

Original logic: MIT. Upstream SimpleVOut retains ISC; Gowin EDA/IP retains vendor terms. No historical ROMs are included.

Tracked under KonSol RetroStation RS-003: https://github.com/AIDevelopersMonster/KonSol-RetroStation/blob/main/docs/ROADMAP.md