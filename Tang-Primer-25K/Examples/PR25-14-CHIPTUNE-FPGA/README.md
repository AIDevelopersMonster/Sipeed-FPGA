# PR25-14: CHIPMUSIC — Animated pixel art and original music ON Tang Primer 25K

**Status: BUILD PASS + CURRENT-BUILD INSPECTOR PASS (SHA256, SIZE, 9/56 BSRAM, 9 pROM, SETUP/HOLD 0/0, SELECTED NEGATIVE PATHS 0); BOARD NOT TESTED. PLL / CLOCK-RELATIONSHIP WARNINGS TA1123/TA1117 REMAIN.** This is FPGA hardware logic (not a video thumbnail, MP4, HDMI input or PC playback). The board outputs its own scene and sound over its working DVI PMOD / HDMI monitor. No SDRAM, SD card, external keyboard or USB Hub required.

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
- Pixel scene ROM is stored as compressed text `assets/scene_zlib.b64`, unpacked to `scene_palette.mem`, `scene_pixels.mem` (audit source), and **eight padded 2048-byte files** `scene_bank0.mem` … `scene_bank7.mem` by PowerShell before Gowin synthesizes the modules. See asset manifest. **The actual bitmap is on-chip, not streamed from the PC.**
- **No SDRAM module is required:** the 14,400 bytes of color indices occupy 115.2 kbits of payload. The banked mapping allocates eight 16-Kbit BSRAM ROM blocks = 128 Kibit (16,384 byte addresses, 1,984 zero padded) of GW5A-25's 1008 Kbit BSRAM capacity, plus 192 bytes of palette. Allocation and mapping remain to be verified in Gowin reports.

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


## 2026-11-15 — Build #2 IF0007 / IF0008: 98,304 LUT4 attempted for image ROM

The operator's second build progressed past the syntax errors, but the Gowin **inference** stage reported:

```text
WARN (IF0007): Attribute value of 'syn_ramstyle/syn_srlstyle' is not applicable (chipmusic_scene.sv:11)
ERROR (IF0008): The number(98304) of LUT4 used to infer "image_rom" exceeds the resource limit(23040) of device GW5A-LV25MG121NC1/I0
GOWIN EXIT: 1
```

**Interpretation:** `image_rom[0:14399]` was being mapped into logic, NOT embedded BSRAM. Merely tagging one large, non-power-of-two memory with `syn_romstyle = "block_rom"` was not enough in this Gowin 1.9.9 build. The FPGA has adequate BSRAM for this image; **98,304 LUT4 are a failed *implementation choice*, not the bitmap's intrinsic resource requirement**.

**Source-only correction:** split the 14,400 bytes into **eight separate 2,048×8-bit ROM arrays**, each with Gowin `/* synthesis syn_romstyle = "block_rom" */` and its own `$readmemh("scene_bankN.mem", image_bankN)`. Synchronize the bank-selection bits along with the bank data, keeping the original single-clock pixel read latency. Builder regenerates all 8 bank files from the same original SHA-checked compressed image; it pads the final bank with 1,984 zero bytes, without changing any visible pixel. Audio, PLL, HDMI, OSER10 reset sync and fixed frequency assumptions are **unchanged**.

Per Gowin's [SUG949 HDL Coding Guide](https://cdn.gowinsemi.com.cn/SUG949E.pdf) (pROM/pROMX9) and [UG285 BSRAM Guide](https://cdn.gowinsemi.com.cn/UG285E.pdf), native block ROM configurations support **2048×8** and `readmemh` initializations with a synchronous read. **This is an attempted vendor-guided BSRAM inference fix, NOT a verified Gowin compile.** If `IF0007` / `IF0008` persists, a follow-up can use direct Gowin pROM primitive instantiation with explicit initialization, rather than weakening the image resolution.

**Safety:** do not program FPGA until BUILD PASS and STA checks. PR25-13 remains the verified HDMI VIDEO+AUDIO backup; this change only modifies the new PR25-14 source files and its build script.


## 2026-11-15 — Build #3 PASS after banked ROM patch

Operator reran the exact source from GitHub commit `a988162` at `20261115_023848511`. **GowinSynthesis passed** after detecting and extracting each of the eight `image_bank0..7` memories. **Placement, routing, timing-analysis phase and bitstream generation all completed** in Gowin 1.9.9Beta-4 Education. This is the first complete PR25-14 build.

```text
GOWIN EXIT: 0
BUILD PASS: artifacts/chipmusic_tp25k_PR25_14.fs
SHA256: 106f396912caf6c2c04fb9dede1c3bdd38dc46bb6a0556cd9c37b30ebdf82a98
GLOBAL SETUP VIOLATIONS: 0
GLOBAL HOLD VIOLATIONS: 0
```

**Caveats and remaining audit:** The source log shows `Extracting RAM for image_bank0..7` and successful bitstream, which is strong evidence the architecture change avoided the previous LUT4 resource overflow. It does **not** by itself tell us the exact **BSRAM block count**: inspect synthesized/netlist/PnR resource report before claiming eight physical BSRAM blocks. `TA1123` warns that `clk_pixel_x5` timing constraint frequency differs from the PLL clock; `TA1117` warns that relationships cannot be calculated between `clk_50mhz`, `clk_pixel_x5`, `clk` and `clk_audio`. These warnings also occurred on the previously working PR25-13, but are not timing sign-off. The log still contains `EX3791` on truncating scene coordinate arithmetic and `NL0002` about optimizing HDMI packet module hierarchy; neither, in isolation, proves loss of picture or sound.

**Read-only inspection before programming** (no second build and no hardware write):

```powershell
& .\Tang-Primer-25K\Examples\PR25-14-CHIPTUNE-FPGA\Inspect_Build.ps1
```

Paste that compact report before PR25-14 hardware programming. User-verified PR25-13 remains the control. The initial synthesis warnings and fixes are preserved above in chronological order.


## 2026-11-15 — Inspector defect corrected after repeated BUILD PASS

The operator reran `Build_Chiptune.ps1` on the exact same repository source and obtained another **BUILD PASS (Gowin EXIT 0; global Setup/Hold violations 0/0)**. The new local `.fs` SHA-256 was `cd9299d6ef75c73f8d37885d211fca2c82c38a2bc4b9d32d9b5be18bb8dc092d`, whereas the preceding successful build yielded `106f396912caf6c2c04fb9dede1c3bdd38dc46bb6a0556cd9c37b30ebdf82a98`. A difference in hashes is **not evidence that either .fs is defective**; its cause was not isolated (tool flow, build-directory effects, nondeterminism, etc.).

The `Inspect_Build.ps1` previously **hardcoded the first successful SHA256**, so it refused to inspect the later successful build:

```text
Unexpected PR25-14 .fs SHA256: cd9299d6ef75c73f8d37885d211fca2c82c38a2bc4b9d32d9b5be18bb8dc092d
```

**Fix:** inspect now validates SHA-256 **and byte count** against `artifacts/PR25_14_manifest.json` written by the same local build, with a strict 64-digit hexadecimal hash format. `Program_SRAM.ps1` already used the correct per-build manifest check and requires no change. This is a **read-only inspector fix**: it does not rebuild and does not program the FPGA. Do not consider PR25-14 hardware verified until a successful SRAM-only test of this exact build and the VIDEO/AUDIO observation.

Re-run the same `git fetch` + `git restore` commands from above, then **only** `Inspect_Build.ps1`. Do **not** run `Build_Chiptune.ps1` again just to satisfy the inspector.



## 2026-11-15 — broken inspector script reconstructed (parse error)

After updating GitHub to inspect the current build manifest, the operator ran `Inspect_Build.ps1`, but PowerShell failed to **parse the script at line 22**, because the previous update accidentally duplicated the script and left this line incomplete: `if($expected -notmatch '^[0-9a-fA-F]{64}`. This was a publishing/editing error in the **inspector source**, **not** a failure in the `.fs`, Gowin, FPGA or user's workflow. No hardware was programmed.

The affected file has now been reconstructed from its intact original read-only analysis core and complete per-build SHA256 + byte-count comparison. The malformed duplicated tail has been discarded. Verify the new script by parsing it before execution if desired: `$tok=$null; $err=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path .\Tang-Primer-25K\Examples\PR25-14-CHIPTUNE-FPGA\Inspect_Build.ps1).Path,[ref]$tok,[ref]$err) | Out-Null; $err` (no errors expected). This check uses built-in PowerShell AST, does not run the build or program any hardware.

Latest operator `Build_Chiptune.ps1` PASS: bitstream SHA256 `cd9299d6ef75c73f8d37885d211fca2c82c38a2bc4b9d32d9b5be18bb8dc092d`; Setup/Hold 0/0. This is the current build to be audited, not the previous `106f...` build.


## 2026-11-15 — Inspector PASS, verified FPGA resources; SRAM test permitted

Operator successfully ran the corrected `Inspect_Build.ps1`. PowerShell AST parser found **no syntax errors**. The inspector verified the exact current binary SHA256 **`cd9299d6ef75c73f8d37885d211fca2c82c38a2bc4b9d32d9b5be18bb8dc092d`**, size **2,133,780 bytes**, against the current local build manifest (not a previous build's hash).

Observed report:

```text
GLOBAL SETUP VIOLATIONS: 0
GLOBAL HOLD VIOLATIONS: 0
NEGATIVE PATHS IN SELECTED STA TABLES: 0
BSRAM | 9
BSRAM | 9 / 56 | 17%
--pROM | 9
NO FPGA PROGRAM/BUILD/FLASH OPERATION PERFORMED.
```

This demonstrates that ROM banks now synthesize into **on-chip BSRAM** (9 pROM blocks allocated for the image/palette), resolving the earlier 98,304-LUT overflow. The original ROM layout intention was eight 2048×8 image banks plus palette; the resource report establishes **9 pROM**, but block-to-source mapping should be taken from the synthesis netlist if exact attribution becomes necessary.

**Timing limitations:** 0 global Setup/Hold and 0 *selected* negative paths are NOT an unconditional full STA sign-off. Gowin `TA1123` reports `clk_pixel_x5` constraint vs PLL output disagreement and `TA1117` reports unknown clock relationships; this is known also for the previously video+audio-working PR25-13 but remains open. Recovery/Removal may be excluded by the report selection, so no claim of complete timing closure.

**Go/no-go:** suitable for a **reversible FPGA SRAM-only demonstration**, leaving upstream Golden and user-verified PR25-13 backup untouched on disk. Use the existing `Program_SRAM.ps1 -Program` only when ready to temporarily replace the running FPGA configuration (no Flash). Verify `SRAM PROGRAM EXIT: 0`, then report **VIDEO: image? animation?** and **AUDIO: audible melody?** separately. To restore verified PR25-13: `..\\PR25-13-A2600-SDC-DUTY50\\Program_SRAM.ps1 -Program`. Do not claim PR25-14 BOARD PASS before the actual display and audio test.
