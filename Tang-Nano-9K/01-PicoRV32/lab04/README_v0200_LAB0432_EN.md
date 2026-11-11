# LAB-04.3.2 — PiKoSoL Interactive Shell v0.2.0-alpha

This is an **experimental package**, based on hardware-validated v0.1.8b1. It is not yet Icarus/Gowin/STA/board certified. In this revision the PicoRV32 executes an ASCII line-oriented CLI on real RV32I ROM instructions, with 16 KiB ROM and 1 KiB CPU scratch RAM. Terminal text uses a separate pixel-clock 32x76 VRAM ring with TERM (29 visible rows) and GFX (graphics canvas with status and four log rows) modes.

Commands: `HELP`, `INFO`, `MEM`, `STATUS`, `LED 0..6`, `LED ?`, `GFX`, `TERM`, `CLS`, `OBJ A/B`, `MOVE I/J/K/L`, `COLOR R/G/U/W`, `SIZE +/-`, `PANEL`, `KEYS`. All line commands require Enter; Backspace and Ctrl-P (one entry) are implemented. `KEYS` is available after `GFX` and enables immediate i/j/k/l movement without Enter; `T` returns to TERM. Canvas bounds x=32..448, y=112..344.

Pinned vendor HDMI, clocks, TMDS, LED/graphics CDC and UART byte CDC are unchanged. No OS, file-system, networking or preemptive scheduling claims. In Windows run `tools/test_lab04.ps1` (including full Icarus + real PicoRV32 RTL simulation), then Gowin CPU build and `tools/check_sta_v018b.py` on **the same job**. Only after timing and physical CDC PASS may the `.fs` be loaded into volatile SRAM using Gowin operation index 2. Board validation: `tools/test_lab0432_board.ps1` with COM10 and HDMI checkpoints.
