# PiKoSoL 20K / PicoRV32 — first native RTL implementation (2026-11-10)

**Status: SOURCE CANDIDATE. NOT RTL SIM PASS / NOT GOWIN PASS / NOT BOARD PASS.**
The 9K PiKoSoL and the EX20-05.16 LiteX/VexRiscv FPGA image remain unchanged.

This directory contains the first complete *source candidate* for a native Tang Nano 20K PiKoSoL:
- PicoRV32 CPU and the 9K PiKoSoL shell, staged from unchanged upstream 9K sources.
- An expanded 32 KiB boot ROM and 8 KiB scratch RAM, 95-character input buffer.
- Native 1280 x 720 DVI/HDMI pixel compositor (not an embedded 640 x 480 crop).
- 160 x 60 visible ASCII characters, circular 160 x 64 byte text backing storage and 8 x 12 glyphs.
- Eight 12-bit-coordinate sprite descriptors, atomic frame COMMIT; CPU shell extends OBJ A..H.
- Six active-low on-board LEDs (pins 15..20), UART (pins 69/70), and HDMI HUD.
- Reuses EX20-05.16's pinned Sipeed HDMI IP, the original pinned PicoRV32, and
  the validated 9K CPU/MMIO/CDC/UART sources. No VexRiscv or LiteX is in this build.

**Not implemented in this first hardware gate:** microSD SPI/FAT32, 8 MiB SDRAM,
WS2812 RGB, audio, full arbitrary framebuffer. These are later increments, not
restrictions inherited from 9K.

## Run on the Windows Gowin workstation

From the repository root:
```powershell
git fetch origin
git switch feature/pikosol-20k-picorv32-port
Set-Location C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-06-PiKoSoL-PicoRV32
python .\tests\test_contract.py
.\build.ps1 -StageOnly
.\tests\run_sim.ps1
.\build.ps1
```

The stage script expects the old `01-PicoRV32/lab04` source tree and
`01-PicoRV32/vendor/picorv32/picorv32.v`. The `build.ps1` fetches the pinned
PicoRV32 and 20K HDMI source only if missing; it does **not** change the
old 9K source files. It stages all 20K build inputs in a unique ignored
`build/candidate_*/work` directory, including generated 8192-word ROM HEX.

**Do not program** the new bitstream until the Gowin PnR report has been
reviewed for device compatibility, resource fit, setup, hold,
recovery/removal, and 27 MHz↔pixel-clock CDC timing. The only authorized
future programming operation is a separately confirmed `--run 2`
**SRAM-only** update. No Flash/JTAG calls are in `build.ps1`.

## Provenance and test limits

Six static Python source-contract checks were performed here and passed.
Python `stage.py` was syntax-checked. **Icarus Verilog, Gowin synthesis,
PnR, STA, and physical-board tests could not be run in this environment.**
A static test is not an RTL simulation pass. The `tests/run_sim.ps1`
script is provided for the Windows workstation with Icarus installed.

The video color pipeline, font RAM inference, eight-object fanout and
raster pipeline timing are candidate designs; actual resource/timing
assessment is mandatory before a new `.fs` is loaded.

Video source reference: `../EX20-05-CPU-HDMI` confirmed 720p HDMI on
LiteX/VexRiscv, but that earlier result cannot be transferred as a
board-level PASS to this new PicoRV32 design.

Full original source contract: `01-PicoRV32/lab04`.
