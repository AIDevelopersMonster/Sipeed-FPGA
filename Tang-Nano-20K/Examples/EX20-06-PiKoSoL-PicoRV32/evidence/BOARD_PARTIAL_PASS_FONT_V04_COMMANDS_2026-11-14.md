# EX20-06 FONT v0.4 — first operator hardware command session (2026-11-14)

**Evidence source:** direct operator-provided transcript, on a Tang Nano 20K FPGA previously loaded with FONT v0.4. Source-built candidate `candidate_20261114_070316_093` / bitstream SHA256 `DD75E28DAE5F4D3CF8B2C4BCDABEF7849303A9C029D71117EBAC252F2012DCBC` is the intended image. The operator transcript **does not include the programming utility output or an image hash readback**, so this identity is a *session-level inference from the banner and features*, not independent cryptographic proof of the running fabric.

## Observed serial output

```text
PiKoSoL 20K / PicoRV32 v0.3 candidate
PicoRV32 / Tang Nano 20K / native HDMI 1280x720
FONT 2 default (80x30). HELP lists commands.
PiKoSoL> HELP
HELP INFO MEM LED N|? GFX TERM CLS KEYS FONT 1|2
OBJ A-H MOVE I|J|K|L COLOR R|G|U|W
SIZE +|- PANEL STATUS; single-key commands + Enter.
CTRL-P recall previous command. No file system yet.
PiKoSoL> INFO
PiKoSoL LAB-04.3.2 / PicoRV32 RV32I
Tang Nano 20K; 1280x720 HDMI; UART 115200 8N1
MODE: TERMINAL
PiKoSoL> MEM
ROM 32KiB @00000000; RAM 8KiB @00010000
LINE 95 characters; history 1; 160x60 text VRAM.
PiKoSoL> LED 1
C=1
PiKoSoL> LED 2
C=2
PiKoSoL> LED 6
C=6
PiKoSoL> LED 0
C=0
PiKoSoL> ?
M=00
PiKoSoL> LED 3
C=3
PiKoSoL> ?
M=07
PiKoSoL> COLOR R
V
PiKoSoL> R
V
PiKoSoL> GFX
MODE: GRAPHICS. MOVE IJKL, OBJ A-H.
PiKoSoL> LED 0
C=0
PiKoSoL> CLS
CLEAR: HDMI console history cleared.
PiKoSoL> HELP
HELP INFO MEM LED N|? GFX TERM CLS KEYS FONT 1|2
OBJ A-H MOVE I|J|K|L COLOR R|G|U|W
SIZE +|- PANEL STATUS; single-key commands + Enter.
CTRL-P recall previous command. No file system yet.
PiKoSoL> TERM
MODE: TERMINAL
PiKoSoL> KEYS
ERR: ARGUMENT
PiKoSoL> KEYS FONT 2
ERR: UNKNOWN
PiKoSoL> SIZE +
V
PiKoSoL> +
V
PiKoSoL> FONT 1
FONT 1: 160x60 (8x12)
PiKoSoL> FONT 2
FONT 2: 80x30 (16x24)
PiKoSoL> PANEL
+---------------------+
| PiKoSoL 1280x720     |
| LED [......]        |
| OBJ=A X=064         |
| Y=0B4 W=70          |
+---------------------+
PiKoSoL>
```

## What the transcript establishes

1. **CPU ROM and UART shell:** board produced the new 20K banner, updated HELP/INFO, MEM, TERM/GFX, PANEL and FONT command acknowledgements. This is **BOARD PARTIAL PASS**.
2. **LED control register readback:** after `LED 0`, `?` returned `M=00`; after `LED 3`, `?` returned `M=07`. This establishes register write/read consistency for the tested masks. Physical LED observations are **not in this transcript**.
3. **Object descriptor width readback:** initial object A width in generated ROM is 96 decimal (0x60); the sequence `SIZE +`, `+` increments it twice by 8 to 112 decimal (0x70), and PANEL subsequently reports `W=70`. Its X=0x064 (100), Y=0x0B4 (180) also match ROM defaults. This is meaningful CPU-side state readback, not proof of on-screen sprite width.
4. **FONT 1 and FONT 2** command parser/CPU TX routine generated the expected acknowledgement strings. The actual physical font scale and full 160x60/80x30 HDMI geometry **require a photo, monitor observation or independent hardware video check**; the transcript alone does not prove the pixel output changed.
5. **Expected errors, not regressions:** `KEYS` in TERM returns `ERR: ARGUMENT` by design; it is enabled only after `GFX`. `KEYS FONT 2` is not a valid compound command in this line parser. Enter commands separately.
6. **Minor firmware wording issue:** MEM always says `160x60 text VRAM`, but physical backing is **160x64 bytes** and visible terminal is **160x60 in FONT 1** or **80x30 in FONT 2**. Correct wording in a *subsequent* ROM revision; do not silently patch the just-qualified v0.4 bitstream.
7. No filesystem claimed or demonstrated.

## Next narrow hardware test

```text
GFX
PANEL
OBJ C
PANEL
MOVE L
PANEL
COLOR R
PANEL
OBJ H
PANEL
KEYS
T
HELP
FONT 1
HELP
FONT 2
HELP
```

Verify visible graphics and LED response separately, observe actual HDMI glyph scaling, and check screen clearing/new text after FONT switches. This test should be undertaken with awareness that live `KEYS` changes parsing behavior, and `T` is the documented escape to TERM. Screen content can transiently disappear while BSRAM clears.

**Status:** FONT v0.4 ROM command behavior — BOARD PARTIAL PASS. Gowin STA had PASS; no claim of complete hardware signoff, full 8-object visual test, filesystem, or verified resolution from monitor OSD. Preserve older working STA-5 and SRAM-only programming safeguards.
