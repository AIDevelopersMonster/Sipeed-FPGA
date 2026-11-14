# EX20-06 — first real-board evidence: HDMI video + PicoRV32 shell HELP

**Date:** 2026-11-14. **Status:** BOARD PARTIAL PASS (visual output / text / interactive HELP only), NOT overall BOARD PASS.

## Evidence supplied by board operator

1. A photograph of the connected screen shows the on-screen PiKoSoL 20K/PicoRV32 v0.3 candidate introductory text, help hint and visible `PiKoSoL>` prompt on a blue background. This is observed HDMI text output on the real device, not inferred from static RTL. Photo was supplied in the conversation; **photo binary has not been committed to the repository**.
2. Operator subsequently submitted a successful shell interaction:

```text
PiKoSoL> help
HELP INFO MEM LED N|? GFX TERM CLS KEYS
OBJ A-H MOVE I|J|K|L COLOR R|G|U|W
SIZE +|- PANEL STATUS; single-key commands + Enter.
CTRL-P recall previous command. No file system yet.
PiKoSoL>
```

This directly confirms the command processor accepted and executed `HELP`, displayed the intended 20K extended help text (including `OBJ A-H`), and returned to its prompt. The HELP text's mention of A-H is **not** yet proof of functionality of all eight graphical objects.

## Candidate identity and preceding acceptance evidence

The planned and STA-5 signed-off SRAM candidate was `candidate_20261114_062849_118`, `.fs` size **7,264,150 bytes**, SHA256 `1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2`. Operator has **not supplied the JTAG programming transcript or runtime bitstream fingerprint with these two observations**, so do not assert an independently verified on-board bitstream identity from photo + HELP alone. The on-screen v0.3 / HELP contract is consistent with this port.

Previous PC evidence: contracts 12/12 PASS; renderer and reset Icarus PASS; STA-5 PASS with zero setup/hold violations and zero TNS across CPU/pixel/serial; recovery and removal positive; pin 88 bank3 LVCMOS33 VCCIO 3.3V reported in fitted .pin.html. `PR1014` (generic routing on `clk27_d`) remains logged and was accepted only as a scoped experimental SRAM risk, not silenced.

## Acceptance status

| Subsystem | Hardware evidence | Status |
| --- | --- | --- |
| FPGA running user candidate | Visible text/banner and prompt | PARTIAL: bitstream identity not independently checked |
| HDMI image / text | Photograph with readable PiKoSoL text | BOARD VISUAL PASS for initial text output |
| PicoRV32 ROM + shell | `help` executed; banner/prompt | BOARD COMMAND PASS for HELP |
| Interactive UART | HELP transcript supplied; transport not explicitly identified | Operating shell proven; UART physical COM25 not independently documented here |
| Native 1280x720 timing | Intended RTL and STA, screen photo | NOT VERIFIED via monitor OSD or measurement |
| All six LEDs | Not yet reported | NOT TESTED |
| Eight objects, GFX, motion, color | HELP advertises A-H, no execution results | NOT TESTED |
| TERM/GFX switching / keyboard / scrolling | No commands or edge tests | NOT TESTED |
| Reset/PLL recovery on board | No reboot observations | NOT TESTED |
| Flash preservation after power cycle | No operator report yet | NOT TESTED |

## Next safe hardware test sequence

No further FPGA programming required for these commands:

```text
INFO
MEM
STATUS
PANEL
LED 6
LED ?
LED 0
GFX
OBJ C
PANEL
MOVE L
COLOR R
PANEL
TERM
HELP
```

These are non-destructive shell controls, not JTAG/Flash/SD writes. Operators should compare physical LEDs versus mask (LED 6 all on, LED 0 all off), photograph GFX output, and note whether the terminal prompt remains responsive. The existing firmware's `INFO` and `MEM` strings are staged for Tang Nano 20K; no actual board run of those commands is reported here.

## Font/readability observation

Operator notes: `Шрифт можно и увеличить` (current 8x12 glyphs appear very small at 1280x720). Preserve current **160x60** mode as a reference. Consider a separately tested optional zoom mode (e.g. 2x, 16x24 glyph display, 80x30 visible), ensuring cursor, ring buffer, scroll, HUD, text pipeline latency and 720p STA are qualified. Do **not** silently change the verified STA-5 bitstream during remaining acceptance tests.

**Release discipline:** A working screenshot and HELP interaction are important board evidence, but not all-function PASS. Record each next observed result separately; never claim the filesystem (HELP explicitly says none), SDRAM/SD, eight objects, or hardware reset tested without operator demonstration.
