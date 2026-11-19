# PR20-03 — PiKoSoL TP20: minimal PicoRV32 computer on Tang Primer 20K Dock

**Status (2026-11-19): BOARD PASS for the running UART/HDMI shell and live PC keyboard; not a standalone firmware release.**
**Type:** a small *bare-metal* RISC-V computer / monitor, not a complete operating system.
**Board:** Sipeed Tang Primer 20K **Dock**, distinct from Tang Nano 20K and Tang Primer 25K.

## What is actually verified

The operator supplied photographs and real serial output from the active PiKoSoL TP20/PicoRV32 configuration.

| Function | Status | Evidence / limit |
| --- | --- | --- |
| PicoRV32 RV32I boot, running firmware | BOARD PASS | `INFO` returns `CPU=PicoRV32 RV32I (THLN33)` |
| UART shell on host PC | BOARD PASS | `HELP`, `INFO`, `CLS`, `TEXT` responded |
| HDMI text display | BOARD PASS | Command output and `SCREEN CLEARED` visible on monitor |
| Immediate keyboard input on HDMI | BOARD PASS | Operator confirmed live-keyboard client works without waiting for Enter |
| Input line case handling | BOARD PASS | `HELP` and `help` accepted |
| Text with argument | BOARD PASS | `TEXT ghbdtn` produced `HDMI TEXT: ghbdtn` |
| `LOAD` / `RUN` execution of independently built binaries | NOT YET VERIFIED | Commands advertised, `APP ... LOADED` status shown; no run acceptance log here |
| Board LEDs, buttons, WS2812B RGB, audio | NOT YET INTEGRATED | Physically present on Dock, no PiKoSoL driver/board test in this experiment |
| MicroSD filesystem, DDR3 driver, USB HID host | NOT YET INTEGRATED | Do not assume usable just because connectors/chips exist |

Do **not** reinterpret a command name in `HELP` as an independently tested capability.
No untested bitstream, broken candidate build, or release is included here.

### Actual running firmware report

```text
PiKoSoL TP20 / PicoRV32 / UART + HDMI
Commands: HELP INFO MEM POKE RAMTEST ADD XOR COLOR CLS BARS TEXT LOAD RUN

CPU=PicoRV32 RV32I (THLN33)
BOOT=00000000 + 2000 bytes
RAM=20000000 + 10000 bytes
VIDEO=30000000; UART=80000008/0C; XMODEM-CRC
SCREEN(hex): 60x2A cells
IDENT0=0x003C2A60 IDENT1=0x00000602
APP @2000C000: LOADED
```

Numbers on `INFO` are **hexadecimal**: boot region 0x2000 = 8 KiB; RAM region 0x10000 = 64 KiB; screen 0x60 × 0x2A = **96 × 42 cells**.
`APP @2000C000: LOADED` is a reported status, **not proof** that an arbitrary executable has been launched.

## Run the verified live keyboard client (PC -> UART -> PicoRV32 -> HDMI)

File: [`PiKoSoL_TP20_LIVE_KEYBOARD.py`](PiKoSoL_TP20_LIVE_KEYBOARD.py).

```powershell
python -m pip install pyserial
python .\PiKoSoL_TP20_LIVE_KEYBOARD.py --selftest
# Close other programs holding COM10:
python .\PiKoSoL_TP20_LIVE_KEYBOARD.py --port COM10
# Option: keep UART output on FPGA HDMI, do not print mirrored text on PC:
python .\PiKoSoL_TP20_LIVE_KEYBOARD.py --port COM10 --hdmi-only
```

The client sends printable ASCII, Enter and Backspace **immediately**, not via `input('PC> ')`.
The FPGA itself performs echo, parsing and video output. Esc closes the PC client, **not** the FPGA.
`Ctrl+P` and the optional `--up-recall` are only for firmware variants that implement one-line history; do not claim that this TP20 image supports them.
UART 115200 8N1. The Windows COM number is host-specific (COM10 in this experiment).
This client does not program FPGA, write flash, modify ROM or change GitHub.

## Canonical launch after recovery: LIVE, not the old PC> console

**Do not use** `TP20_PiKoSoL_Run.ps1 -BoardTest -Demo` as the everyday terminal:
that legacy flow opens `host_console.py` and its line-buffered PC input.
The user verified the **exact** `PiKoSoL_TP20_LIVE_KEYBOARD.py` source
(not a recreated approximation) on the working HDMI/FPGA configuration.

Place [`Start-PiKoSoL-Live.ps1`](Start-PiKoSoL-Live.ps1) and
[`PiKoSoL_TP20_LIVE_KEYBOARD.py`](PiKoSoL_TP20_LIVE_KEYBOARD.py) next
to the original `TP20_PiKoSoL_Run.ps1`. Then start the **normal**
terminal with:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Start-PiKoSoL-Live.ps1 -Port COM10
```

This performs only a PC-side selftest and opens the real-time COM keyboard.
It **does not** reload or reconfigure FPGA.

If the HDMI shows `Waiting for downloader ...`, the **monitor is not running**.
`PiKoSoL_TP20_LIVE_KEYBOARD.py` cannot send an XMODEM image. Use the
explicit **recovery** path:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File .\Start-PiKoSoL-Live.ps1 -Recover -Port COM10
```

The recovery mode calls the already-existing `TP20_PiKoSoL_Run.ps1 -Attach`
to handle the bootloader transfer; the recovery phase may temporarily
show `PC>`. After the recovery console exits, the script starts LIVE.
`-Attach` is supplied to avoid reprogramming FPGA SRAM. The precise
behavior of the local `host_console.py` has **not** been re-inspected
in this session, so recovery completion is **not yet BOARD PASS**.
Do not run the two clients simultaneously on COM10.

The earlier `LOAD` stall and `Launch error = 1` remain an **open
diagnostic issue**; neither this launcher nor a fresh keyboard client
claims to repair the loader firmware. Keep the original working .fs
and monitor.bin intact.

## Actual peripherals on Tang Primer 20K Dock (hardware inventory, not implemented MMIO)

| Device on board | FPGA balls / connections | Expansion proposal |
| --- | --- | --- |
| Six discrete LEDs, active LOW | C13, A13, N16, N14, L14, L16 | `LED`: bitmask, counter, chase, PWM |
| Five pushbuttons, active LOW | S1=T10 (also hardware reset); S2=T3, S3=T2, S4=D7, S5=C7 | `KEYS`: debounced press/release events, menus and games |
| Five DIP switches | B10, E9, E8, T4, T5 | Read-only input; B10 is also RECONFIG_N — handle carefully |
| **One WS2812B RGB LED** (not a three-pin simple RGB LED) | T9, also `MIC_LED_DAT` | `RGB R G B`, `RGB OFF`, color fade, brightness |
| Stereo audio DAC PT8211 + LPA4809 headphone amplifier + 3.5 mm jack | HP_BCK=N15; HP_WS=P16; HP_DIN=P15; PA_EN=R16 | `BEEP`, `SOUND`, tone generator, PCM samples |
| HDMI | Existing active path | Keep current terminal intact |
| MicroSD slot on compute module | SDIO peripheral (requires controller) | FAT read-only first; programs and files later |
| On-module DDR3 (128 MiB physical) | DDR3 controller IP required | Expand the current **64 KiB mapped RAM**, not automatically accessible |
| USB OTG through USB3317 / ULPI | Separate host controller/stack needed | Direct USB keyboard at a later stage |

**Electrical/build constraints (do not skip):**
- S1 / T10 is shared with reset; preserve recovery/boot behavior. Prefer S2-S5 for user control.
- S2-S5 and DIP SW2-SW5 use **1.5 V I/O** (LVCMOS15), whereas most LED/audio/RGB pins are 3.3 V. Never assign LVCMOS33 to a 1.5 V bank.
- T9 is a configuration SSPI-capable pin; using WS2812 may require `set_option -use_sspi_as_gpio 1`.
- A13 / C13 are READY / DONE pins: to repurpose them for LED1 / LED0, Gowin options `-use_ready_as_gpio` and `-use_done_as_gpio` are required. Preserve normal programming behavior.
- WS2812B expects precisely timed **serial** data, not independent R/G/B GPIO signals.
- PT8211 uses 16-bit **LSB-justified** framing; do not drive it with unmodified standard I2S timing.
- Compare the pinout and options against the **actual installed Dock PCB revision and the working CST** before building.

Reference pinouts: [Sipeed Primer 20K](https://wiki.sipeed.com/hardware/en/tang/tang-primer-20k/primer-20k.html) and [Dock pinout cross-check](https://github.com/terenceang/tang-primer-20k-starter/blob/main/docs/pinout.md).
The published pinout is a *reference*, not a declaration that these signals are already present in this build.

## How to grow the minimal computer without losing the verified baseline

1. **LED register**: add a documented read/write MMIO LED mask and simple monitor command; independent hardware test before acceptance.
2. **Key/DIP input**: synchronizers + debouncing; capture button events; reserve S1 for reset unless proven safe.
3. **WS2812**: timing generator, a small RGB MMIO register; board test individual colors.
4. **Audio**: timer/PCM source -> PT8211 serial interface -> amplifier enable -> headphones; verify with a safe fixed-level tone.
5. **Application ABI**: specify entry point, stack, memory reservations, loader packet format and return-to-monitor behavior. Verify a stand-alone Hello program from RAM before adding more.
6. **microSD/FAT read-only**: list and load a known file; avoid write support initially.
7. **USB keyboard / autonomous operation**: only after USB host controller and HID are verified.

Do not select new MMIO register addresses until auditing the existing decoder for collisions with
`0x30000000` (VIDEO), `0x80000008/0C` (UART), the boot map, loader and RAM.
For each feature use *RTL sim -> Gowin build/STA -> SRAM board test*; promote to BOARD PASS only with real output.
Keep the currently functioning bitstream untouched; no Flash writes and no GitHub release from a candidate.

## Programs possible on PicoRV32

| Example | What it demonstrates | Implementation state |
| --- | --- | --- |
| Hello / integer arithmetic | RV32I executable, UART/HDMI output | Proposed independent application; loader ABI/test required |
| Counter / LED runner | CPU writes to LED MMIO | Requires LED driver |
| Buttons / reaction-time game | CPU reads key events and timer | Requires key inputs and timer |
| Conway's Game of Life / Snake / text UI | Pure computation + HDMI text | Needs application interface + tested memory/text API |
| Tone keyboard / mini-synth | Keys -> CPU -> PCM/tone -> PT8211 | Requires key and audio drivers |
| RGB palette / color music | RISC-V sends WS2812 command | Requires RGB driver |
| Memory viewer / ALU benchmarks | Integer operations, memory diagnostics | Compatible in principle; test as an application |
| Tiny BASIC or Forth | Interactive language runtime | More memory/runtime integration; NOT running yet |
| FAT browser / program loader | microSD and executable loading | Requires read-only SD driver and application ABI |

Software should initially target **RV32I integer instructions**, e.g. GCC/Clang target
`-march=rv32i -mabi=ilp32`, but final linker addresses, MMIO ABI, stack, and `RUN`
behavior must be established from the *working source* rather than guessed.
Do not assume Linux, Windows, multiplication extension M, hardware FPU, full libc or an OS.

## Provenance and remaining work

The board demonstrated above reports firmware build `THLN33`; its exact **RTL sources, matching .fs, build TCL and SHA256 have not been imported into this folder**.
The existing repository already contains other PiKoSoL implementations on different boards;
they are architectural references, **not** substitutes for the exact TP20 image running here.

This record deliberately distinguishes **BOARD PASS from intended extensions**.
Once the operator supplies the matching working build, add only its verified source + bitstream + reproducible build recipe and hash.
