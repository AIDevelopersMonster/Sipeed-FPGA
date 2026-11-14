# PR25-14: CHIPMUSIC — Animated pixel art and original music ON Tang Primer 25K

**Status: FIRST BUILD FAILED (Gowin parser EX3863/EX2656); SYNTAX PATCH COMMITTED; REBUILD PENDING; HARDWARE NOT TESTED.** This is FPGA hardware logic (not a video thumbnail, MP4, HDMI input or PC playback). The board outputs its own scene and sound over its working DVI PMOD / HDMI monitor. No SDRAM, SD card, external keyboard or USB Hub required.

## FPGA-generated image and melody

- Scene: 160x90, 64-color indexed image generated from the original pixel-art illustration in our ChatGPT conversation, stretched by 4x hardware to 640x360 pixels centered in HDMI's 720x480 active area. Pixel image data are in on-chip BRAM, palette in LUT or ROM. No framebuffer or memory controller. We use the artistic image as a **visual background only**, then synthesize color bars/twinkling pixels as actual live logic.
- Audio: original looping 32-step song in three synthesized voices (square melody, square arpeggio and triangle-like bass). Notes are generated in FPGA at the nominal 48kHz audio clock and embedded as 16-bit stereo LPCM in real HDMI Audio Data Islands using the exact packet system that worked in PR25-13. The tune was written for this demonstration, and is not a commercial soundtrack.
- Scene's virtual equalizer changes with frame-count and each music beat (through 2-FF synchronization). It really animates on the board and does not depend on CPU or PC.
- Timing: reuse the **known-working PR25-13** PLL RTL, x5-clock serializer reset synchronization, HDMI packet assembler/encoder, native DVI PMOD pinout. New top bypasses A2600 game logic.
- Hardware mode: approximately HDMI 720x480/60Hz, from existing 28.636MHz/143MHz PLL, subject to monitor recognition and toolchain. Source picture is 16:9 inside 4:3 480p timing; black bars around the pixel image.

## Dependencies / design integrity

- Tang Primer 25K GW5A-25A, DVI PMOD physically wired **exactly as for working PR25-13**.
- Windows PowerShell 7 and local Gowin 1.9.9Beta-4 Education.
- Existing PR25-13 build and its exact workspace (`artifacts/sdc50_manifest.json`). The build checks source commit and PR25-13 serializer SHA-256; it refuses to silently fall back to an unverified source tree.
- Pixel scene ROM is stored as compressed text `assets/scene_zlib.b64`, unpacked to `scene_palette.mem` and `scene_pixels.mem` by PowerShell before Gowin synthesizes the modules. See asset manifest. **The actual bitmap is on-chip, not streamed from the PC.**
- **No SDRAM module is required:** the 14,400 bytes of color indices use 115.2 kbits of GW5A-25's 1008 kbits block SRAM, plus 192 bytes of palette.

## Operator steps — BUILD ONLY

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/Examples/PR25-14-CHIPTUNE-FPGA"
& .\Tang-Primer-25K\Examples\PR25-14-CHIPTUNE-FPGA\Build_Chiptune.ps1
```

The script builds in its own ignored `work/run_...` directory and outputs `artifacts/chipmusic_tp25k_PR25_14.fs` and manifest. It does **not** program the FPGA. Report Gowin EXIT, Setup/Hold counts and compiler warnings first. The design has **not** been compiled or board tested by the assistant, because Gowin runs only on the operator's Windows machine.

## Experimental SRAM-only programming — *after* successful build and STA review

```powershell
& .\Tang-Primer-25K\Examples\PR25-14-CHIPTUNE-FPGA\Program_SRAM.ps1 -Program
```

If the experiment fails or if the familiar output is needed again, restore the verified PR25-13 firmware in SRAM using:

```powershell
& .\Tang-Primer-25K\Examples\PR25-13-A2600-SDC-DUTY50\Program_SRAM.ps1 -Program
```

Do **not** write persistent FPGA Flash. JTAG must remain available. Firmware does not touch BL616.

## Acceptance tests

1. Gowin synthesis + PnR produces a new `.fs` (SHA256 recorded).
2. Global setup/hold violations = 0, and no new negative Recovery/Removal paths for OSER10; clock warnings `TA1123` must be reviewed rather than hidden.
3. Successful `SRAM PROGRAM EXIT: 0` and correct JTAG device GW5A-25A.
4. HDMI monitor displays colored 8-bit pixel scene with moving bars/sparkles.
5. Monitor/TV outputs an audible and changing three-voice *melody*, not a static tone. Record both VIDEO and AUDIO separately.

**Do not declare BOARD PASS before tests 3–5.** Previous PR25-13 remains the only user-verified video+audio build as of this source commit.


## 2026-11-15 — first Gowin build error and compiler-compatibility patch

The operator ran the original `Build_Chiptune.ps1` at `20261115_022112558` (Gowin 1.9.9Beta-4 Education). Parsing `chipmusic_scene.sv` failed at lines **32** and **44** with `EX3863 Syntax error near 'inside'` and `EX2656 SystemVerilog keyword 'inside' used in incorrect context`. The module was ignored (`EX3928`); Gowin returned **EXIT 1**. This is a **source syntax defect**, not a PnR, STA, ROM, HDMI or audio hardware finding. There was NO successful `.fs` and NO FPGA programming.

**Fix:** rename only the illegal local net declaration `wire inside` to `wire visible_region`, and its one reference `inside_q <= visible_region`. All pixel/ROM/audio behavior remains unchanged. Also remove declaration-time initialization of `audio_l`, `audio_r`, and `beat_toggle` outputs in `chipmusic_audio.sv` to prevent Gowin `EX2478` warnings; the existing synchronous reset branch already initializes those registers when `!pll_lock` is asserted. The author has NOT run Gowin after this patch; the next build may expose additional errors.

Run the **exact same three commands** in the 'Operator steps — BUILD ONLY' section (`git fetch`, `git restore`, `Build_Chiptune.ps1`). Do **not** run `Program_SRAM.ps1` until there is an actual BUILD PASS and timing report review. PR25-13 (SHA256 `22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a`) remains the working, preserved VIDEO+AUDIO reference.
