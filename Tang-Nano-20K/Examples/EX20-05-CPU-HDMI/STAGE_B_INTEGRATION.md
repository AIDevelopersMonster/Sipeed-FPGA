# EX20-05 / Stage B — one FPGA image: LiteX VexRiscv + Wishbone video + HDMI

**STATUS (2026-11-09): integration HDL and LiteX build scripts committed; Gowin synthesis, constraints, STA, firmware integration and real-board CPU+HDMI not yet passed.** Stage A `video_wb_overlay.v` is independently **SIM PASS**. EX20-01 HDMI and factory LiteX were independently **BOARD PASS**, in **different** FPGA images.

## New integrated SoC

```text
27 MHz onboard oscillator
   +--> LiteX CRG PLL 48 MHz ---> VexRiscv_Min, Boot ROM, UART, SDRAM
   |                                    |
   |                                  Wishbone
   |                                    |
   |                             0xB1000000 VIDEO_BASE
   |                             Video staging / COMMIT
   |                                    |
   +--> Gowin TMDS_rPLL/CLKDIV --> 74.25 MHz pixel domain
                                        |
                                  frame-boundary commit
                                        |
                              1280x720 RGB + HS/VS/DE
                                        |
                             vendor protected DVI_TX_Top
                                        |
                           HDMI pins 33..40 (differential)
```

The overlay emits one rectangle over a solid background; it does **not** use SDRAM for pixels. The LiteX system retains SDRAM/UART for program execution. Clock outputs and constraints require independent verification.

## Upstream sources and versions

- LiteX board/target: `litex_boards.targets.sipeed_tang_nano_20k.BaseSoC`, using the **user-installed version** (currently not pinned or proven compatible with scripts). The [historical LiteX board target](https://github.com/litex-hub/litex-boards/blob/6b8a5d35c03e408f738a9667c0497f31e25bf0b7/litex_boards/targets/sipeed_tang_nano_20k.py) has GW2AR-18C, 48 MHz, DDR PHY and VexRiscv support.
- Sipeed HDMI upstream pinned at commit `e23949a0a77381b94960cbc4e97a7c5e5ba8d222`. `prepare_vendor.ps1` downloads the original encrypted `dvi_tx.v` and `TMDS_rPLL.v` **locally** under `vendor/`; their source URLs, sizes and calculated SHA-256 are recorded in `vendor_manifest.json`. Original reference [Sipeed HDMI project](https://github.com/sipeed/TangNano-20K-example/tree/main/hdmi).
- Differential HDMI pin locations from official CST: data (35/36, 37/38, 39/40), clock (33/34), 27 MHz oscillator pin 4, UART from board platform pins 69/70.
- Gowin DVI IP is vendor-protected, and compatibility between Sipeed's original Gowin v1.9.11 and the user's Gowin v1.9.9 Education **is unverified**. If synthesis fails on encrypted IP, first investigate tool/IP compatibility, not RTL.

## Files

- `rtl/video_wb_overlay.v`: Wishbone staging, CDC handshake, frame-boundary commit (Stage A SIM PASS).
- `rtl/video_hdmi_bridge.v`: pixel timing 1650x750 @ nominal 74.25 MHz, master RGB, Gowin PLL/CLKDIV, DVI_TX_Top.
- `build_soc.py`: LiteX SoC with VexRiscv, SDRAM and UART, Wishbone slave `VIDEO_BASE=0xB1000000`, 256-byte region, CPU/pixel clocks and physical HDMI outputs.
- `prepare_vendor.ps1`: pinned upstream vendor sources.
- `run_build.ps1`: default generate-only; `-Build` opts into Gowin synthesis and PNR. **Neither script programs FPGA or Flash**.
- `firmware/video_demo.c`: example software API; requires separate firmware build and new SoC linker/startup. Not executable on factory BIOS.

## Reproducible Windows commands

The checkout `C:\GitHub\Sipeed-FPGA` has extensive local uncommitted 9K work. **Do not merge main or reset/stash/discard that work**. Fetch only new files:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source=origin/main --worktree -- Tang-Nano-20K/Examples/EX20-05-CPU-HDMI/
& ".\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\prepare_vendor.ps1"
& ".\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\run_build.ps1"
```

Generation first; `run_build.ps1 -Build` only after generator/compatibility preflight:

```powershell
& ".\Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\run_build.ps1" -Build
```

With default `-Python`, expects `C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe`; supply another environment explicitly if that venv only contains host-side test utilities rather than LiteX full toolchain. Icarus alone is insufficient; a Windows RISC-V GCC toolchain, LiteX software generator, Migen, LiteDRAM, litex-boards and Gowin IDE are required. If a failed build occurs, report its full transcript, not merely the trailing exception.

## Concrete acceptance gates

1. **SOC_GENERATE PASS:** LiteX imports and generation complete; SoC map and `VIDEO_BASE` captured, UART and SDRAM retained, no address collision.
2. **SOC_GOWIN_BUILD PASS:** fully built `.fs` for GW2AR-LV18QN88C8/I7 with documented RTL, protected IP acceptance, pin assignment, PNR, timing (48 MHz CPU, 74.25 MHz pixel, 371.25 MHz TMDS serializer), resource report and CDC constraints reviewed. Exit 0 alone is not sufficient.
3. **SOC_FIRMWARE PASS:** native VexRiscv C firmware linked for **new** SoC, verifies VIDEO_ID `0x56323031`, writes background/rectangle/commit, reads status without trap.
4. **SOC_BOARD PASS:** new image programmed to **SRAM only**, UART shows firmware handshake, HDMI visibly changes from software commands, power cycle restores factory LiteX BIOS. Test logs and hashes retained.

**No claim of complete build, simulated full SoC, or board hardware PASS is justified until those gates.**

## Risk and design-review items

- JTAG scan ID only identifies compatible GW2A variants, not exact package/speed.
- The generated HDL targets separate PLLs from the 27 MHz oscillator; ensure Gowin device has resources and both clocks close timing.
- The official Sipeed protected DVI core may not be importable into installed Gowin version.
- Verify generated Gowin differential-pair constraints: some versions express pair pin IDs together in `IO_LOC`, not two independent scalar LVDS signals. Inspect generated CST before accepting synthesis.
- `VIDEO_BASE` must be checked against exact generated SoC address map. The code uses the Wishbone word address shifted two bits to byte offsets.
- The current clock-domain handshaking is simulation-tested, not formally proven CDC and not FPGA constraints-signed off; resets and asynchronous multibit stable transfers need Gowin CDC/STA review.
- Video firmware cannot be run on the factory image because that image has **no VIDEO_BASE peripheral**.
