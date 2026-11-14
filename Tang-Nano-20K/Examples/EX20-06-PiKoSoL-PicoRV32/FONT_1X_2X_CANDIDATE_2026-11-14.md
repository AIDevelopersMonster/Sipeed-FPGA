# EX20-06 FONT v0.4 — larger switchable text, build candidate (2026-11-14)

**Scope:** 1280x720 native timing unchanged. Preserve eight frame-committed graphic objects, PicoRV32, UART 115200, 6 LEDs, VRAM BSRAM inference and the previous board-tested STA-5 bitstream. No FPGA programming is part of this change.

## Desired behavior

- **Default FONT 2:** each 8x12 source glyph is rendered as **16x24** by nearest-neighbor pixel duplication, **80 columns x 30 visible rows**. Scrolling and wrap use a 80x30 viewport.
- **FONT 1:** original 8x12 glyphs, **160 columns x 60 visible rows**. Original terminal behavior is retained for compatibility.
- The backing RAM is **160 x 64 bytes in both modes**; this is deliberate. FONT 2 uses only logical columns 0..79 of each 160-byte physical row; no BSRAM duplication or expensive text buffer copy.
- The firmware command `FONT 1` emits ASCII **FS 0x1C** on CPU UART TX; `FONT 2` emits ASCII **GS 0x1D**. The UART-to-HDMI text bridge recognizes the same command bytes. No XON/XOFF bytes are used. Both commands perform a full text clear and reset cursor/view to row/column 0. Display output may pause briefly while the physical text BSRAM is cleared sequentially (10,240 pixel clocks).
- Font ROM remains **8x12**. A single registered pixel pipeline selects source glyph X/Y using `px[3:1]`/ `(py>>1)%12` in FONT 2, or original 8x12 coordinates in FONT 1.
- `INFO` hardware identity is corrected at the staging step to Tang Nano 20K / HDMI 1280x720.

## Commands

```text
PiKoSoL> FONT 2
FONT 2: 80x30 (16x24)
PiKoSoL> FONT 1
FONT 1: 160x60 (8x12)
```

The prompt/ack text is expected on UART. The HDMI text buffer is intentionally cleared by a mode switch; the first bytes following an immediate switch may be lost during VRAM clear on the current byte-mailbox implementation, so the **hardware test must check subsequent text/HELP after the clear** rather than rely on the first ack being visible onscreen.

## Build from Windows

Update the isolated working tree to `origin/feature/pikosol-20k-picorv32-port` without discarding tracked local edits. Then run from the EX20-06 directory:

```powershell
python -m py_compile .\tools\stage.py
python .\tests\test_contract.py
.\tests\run_sim.ps1
.\tools\build_font_candidate.ps1
```

The new build helper runs Python syntax/contracts, Icarus simulations, isolated Gowin synthesis/PnR/STA and conservative `collect_sta.ps1`; it never programs FPGA. It fails if `STA_GATE.json` is not `PASS_FOR_IO_REVIEW_NOT_BOARD`. Capture the **new candidate's unique SHA256 and .zip reports**.

## Acceptance conditions

- Python 13/13 static contract tests, testbench renderer including FONT modes, reset testbench PASS.
- `LAB04_ROM_BUILD_PASS` with generated `FONT 1/2` parser; 8192-word BRAM ROM still inferred; BSRAM text and glyph ROM remain inferred correctly.
- Gowin PnR actual Fmax pixel >=74.25 MHz; setup/hold/recovery/removal >=0; global setup/hold counts 0; per-clock TNS 0; 6 CDC exceptions remain active; fitted IO RESET pin 88 = LVCMOS33 / BankVccio 3.3. Log `PR1014` for clock route review.
- **The old STA-5 .fs SHA256 `1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2` is no longer the right hash for the FONT revision.** The old SRAM pilot script is deliberately bound to the OLD image; do not bypass that lock for the new candidate.
- Board experimentation only after separate report review and explicit SRAM-only authorization, not before.

**Evidence:** authored source changes and static source analysis are available in GitHub. Updated RTL simulation, actual Gowin PnR/STA, generated ROM SHA, final .fs SHA and FPGA BOARD test are **NOT YET RUN** in this environment.
