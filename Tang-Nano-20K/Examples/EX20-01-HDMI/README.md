# EX20-01 — HDMI 720p on Tang Nano 20K

**Status: SOURCE DOWNLOAD PREP PASS / BOARD NOT TESTED (2026-11-09).** This is a separate FPGA configuration. It **replaces the running factory LiteX SoC in FPGA SRAM** while loaded. It is not an HDMI peripheral added to the original BIOS.

## Source provenance

- Official project: https://github.com/sipeed/TangNano-20K-example/tree/main/hdmi
- Official bitstream: https://github.com/sipeed/TangNano-20K-example/blob/main/hdmi/hdmi.fs
- Raw link: https://raw.githubusercontent.com/sipeed/TangNano-20K-example/main/hdmi/hdmi.fs
- Git blob SHA (not a SHA-256 checksum): `10853620315d7af5885c74f88023375aa14d978a`
- Expected file size: **4,619,320 bytes**
- Gowin project device: `GW2AR-LV18QN88C8/I7`
- RTL top: `video_top`, video timing 1280 x 720 with 1650 total horizontal and 750 total vertical pixels.
- Original RTL testpattern modes: color bar, grid, gray, solid green, blue, red (button cycles mode register; further values depend on RTL behavior).

Operator completed preparation on Windows on 2026-11-09: **4,619,320 bytes; SHA-256 `cb024d255692321a9b7fa22cf603dd89d1cd7875930ad57e00fd2bccf6cf9b0a`; PREP PASS**. The SHA-256 was calculated from the locally downloaded file. Do not confuse Git's blob SHA with SHA-256.

## Safe Windows preparation — NO hardware programming

In PowerShell, in your checkout:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
# On a dirty feature branch, do NOT merge main: extract just required files instead.
git restore --source=origin/main --worktree -- Tang-Nano-20K/Examples/EX20-01-HDMI/prepare_hdmi.ps1
# Use a clean checkout/worktree for future updates.
& ".\Tang-Nano-20K\Examples\EX20-01-HDMI\prepare_hdmi.ps1"
```

This script downloads `hdmi.fs` to the local `artifacts` directory, checks the exact byte count, computes SHA-256 and writes `hdmi_source_manifest.json`. No COM/JTAG is accessed, and no FPGA memory or Flash is written.

## Preferred CLI path (Windows, no Gowin GUI)

The repository includes [program_hdmi_sram.ps1](program_hdmi_sram.ps1), matching the proven Gowin CLI workflow. The default invocation is **dry-run only**. `-Scan` executes read-only JTAG discovery; `-Program` runs the explicitly requested **SRAM Program** operation (`--run 2`). This does **not** program nonvolatile Flash, but it does replace the current live FPGA configuration, so the factory LiteX UART will stop responding until the configuration is restored/reloaded.

On a dirty feature branch, avoid `git pull`. Extract this single file from `origin/main`:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source=origin/main --worktree -- Tang-Nano-20K/Examples/EX20-01-HDMI/program_hdmi_sram.ps1
& ".\Tang-Nano-20K\Examples\EX20-01-HDMI\program_hdmi_sram.ps1"
& ".\Tang-Nano-20K\Examples\EX20-01-HDMI\program_hdmi_sram.ps1" -Scan
```

**Review the scan log and confirm `GW2AR-18C` and the intended board** before running a write. Close COM/JTAG users and connect HDMI. Only then, explicitly opt in:

```powershell
& ".\Tang-Nano-20K\Examples\EX20-01-HDMI\program_hdmi_sram.ps1" -Program
```

The script checks a pinned byte count and SHA-256, performs a scan, requires the expected device string, and saves the programmer transcript. CLI exit 0 is a *programming-command success*, not a substitute for the monitor test or restoration test. The CLI `--run 2` SRAM operation is documented in Gowin Programmer User Guide SUG502.

## Physical test procedure (operator)

1. **Preserve factory baseline:** while the original LiteX image is running, verify `litex>` on COM25 at 115200 8N1; save output/log if needed, then close PuTTY/Tera Term and all COM users. Do not attempt to use the LiteX BIOS with HDMI image loaded.
2. Connect Tang Nano 20K to its supported USB programming interface and connect HDMI to a powered display with 1280x720 support. Confirm board/device identification in Gowin Programmer first.
3. Open **Gowin Programmer**. Select an operation explicitly labeled **SRAM Program** / **SRAM Mode** (naming depends on Programmer version), choose the downloaded `sipeed_hdmi_20k.fs`, and inspect the operation summary **before clicking Program**.
4. **STOP** if any selected operation says `Flash`, `External Flash`, `Embedded Flash`, `Erase` or `Program Flash`, or if the target device does not match the 20K project/device. Never select `Erase`, `SRAM+Flash`, or any persistent configuration mode in this experiment.
5. Run the SRAM-only programming operation and capture the Programmer success/failure log. Observe the HDMI image and press the image-mode key to verify a visible change. Photograph the screen and note display's detected signal resolution and LED behavior.
6. **Recovery:** power-cycle the board (not merely press a fabric RESET) to cause configuration reload from the preexisting nonvolatile source, if the board is configured to do so. Verify `litex>` again on COM25. Do **not** claim preservation of factory BIOS without this check.

## PASS requirements

- Source file checksum/size captured in manifest.
- Programmer confirms correct Tang Nano 20K device and successful **SRAM-only** configuration, with no persistent Flash operation.
- Display visibly shows stable test pattern at 1280x720; key toggles pattern (record what changed).
- Power-cycle restores the previous LiteX BIOS (`litex>`) if this is the baseline.
- Original FPGA Flash remains untouched by the operator's programming command.

Record exact programming mode, screenshot/log and observations. Until these are provided, **BOARD NOT TESTED**.

## Engineering notes

The official example is a raster/video generator plus DVI/TMDS transmitter and PLL. It contains no integration with the factory LiteX CPU; it demonstrates that the video interface can be driven by FPGA RTL in this image. EX20-05 requires a new build to connect a CPU to a video peripheral and to re-check RAM/clock domains, CSR/Wishbone, pin constraints, resource budget and timing. The official HDL may need source-level cleanup before rebuilding; successful prebuilt `.fs` does not prove that a local RTL synthesis will pass.

## Evidence record (to be filled only from physical observations)

- Date/time, board identity:
- Programmer version, target device and *exact operation mode*:
- Local filename, bytes, SHA-256:
- Programming log/result:
- HDMI display and resolution:
- Button press / image transitions:
- Before/after `litex>` result:
- Photo/video / logs:
- Conclusion: `BOARD PASS`, `FAIL` or `INCONCLUSIVE` with reason.
