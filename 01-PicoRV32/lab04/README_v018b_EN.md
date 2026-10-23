# PiKoSoL LAB-04.3.1B / v0.1.8b: Addressable ASCII Console (experimental)

## Goal

Replace the free-running SVO text overlay in the CPU image with a fixed,
readable PiKoSoL screen. Retain CPU, 6 LED MMIO, sprite A/B, clocking,
HDMI TMDS PHY, 28-bit graphics CDC and the original UART firmware protocol.

## Implemented architectural change

- `CONSOLE_ENABLE=1` for CPU variant only; Smoke still uses upstream `svo_term`.
- A static, pixel-rasterized PiKoSoL title and ASCII command menu, x=0..639,
  y=0..95, plus status on the right at x=472..639 and y=120..323.
- Live status: LED mask, last graphics object modified, X/Y, color and mode.
  Graphics registers are mirrored and frame-snapshotted after `commit`.
- 76x4 char-addressable circular UART log at x=16..623,y=352..399.
  Log supports printable ASCII, LF, CR, BS and FF; not ANSI sequences.
- TTY sys->pixel byte CDC is toggle-handshake with a stable 8-bit data bus.
  The console's character RAM is entirely on `clk_pixel` (no RAM CDC).
- One buffered pixel pipeline with backpressure; independent background,
  graphics, text, LED-HUD, encoder and TMDS layers.
- ROM firmware unchanged: 771 instructions, same SHA256.

## Important geometry

Sprite A starts (160,270) sized (96,80), sprite B starts (390,285) sized
(80,64). Their original occupied areas end at y=350 and y=349.
Text log begins at y=352, while LED HUD begins at y=402.
The right status box begins at x=472; initial sprite B ends at x=470.
The text regions therefore do not cover the original initial objects/HUD.
The CPU can command future sprites to overlap UI regions; UI has priority.

## Version gate / evidence

- Complete Python structural/model contract suite: PASS, locally verified.
- v0.1.8b new Icarus RTL simulations: added, NOT run in the build container.
- Gowin synthesis, PnR and post-route STA: NOT run, user Windows required.
- Physical UART / HDMI console v0.1.8b: NOT tested.
- DO NOT flash/program v0.1.8b until both new RTL tests, Gowin and
  `tools/check_sta_v018b.py` all pass. Use volatile SRAM op=2 only then.

## Changes in timing model

The old `svo_term` is synthesized only for the Smoke build and no longer
exists in CPU v0.1.8b. Thus 3 old SDC rules that targeted its physical
registers must not remain in the CPU STA. The v0.1.8b CPU-SDC has 15 rules:
8 LED, 4 graphics, 3 UART-byte CDC. The old v0.1.7 SDC and Smoke SDC are
preserved as regression evidence, but are NOT used for CPU v0.1.8b.

After Gowin, check all 28 graphics plus all 8 UART CDC byte paths and both
TTY synchronizer handshakes with `check_sta_v018b.py`. The old Full28
checker is NOT sufficient for this new design and is NOT to be used as a
programming gate for v0.1.8b.

## Windows testing

cd C:\GitHub\Sipeed-FPGA
$env:PATH = "C:\msys64\ucrt64\bin;$env:PATH"
python .\01-PicoRV32\lab04\tools\verify_kit.py
python .\01-PicoRV32\lab04\tests\test_lab04_v018b_contract.py
& .\01-PicoRV32\lab04\tools\test_lab04.ps1

Only after PASS:

& .\01-PicoRV32\lab04\tools\build_lab04.ps1 -Mode CPU

Audit this NEW build with:

$Lab = 'C:\GitHub\Sipeed-FPGA\01-PicoRV32\lab04'
$Job = Get-ChildItem "$Lab\build" -Directory -Filter 'cpu_*' |
 Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
$Report = Join-Path $Job 'work\impl\pnr\picorv32_lab04_hdmi_nano9k_tr_content.html'
$Log = Join-Path $Job 'gowin_cli.log'
python "$Lab\tools\check_sta_v018b.py" $Report --log $Log

For this experiment, timing checker failures are blockers. Do not
substitute the older v0.1.7 report or suppress unmatched constraints.

## Non-claims

This is a candidate implementation pending real Icarus and Gowin results.
Static source tests are not evidence of physical correct scanout, usable
font sizes, clean scrolling, or full hardware closure. No claim of ANSI,
OS-level process management, arbitrary font loading or a general terminal.
