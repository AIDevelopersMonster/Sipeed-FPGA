# Brus-16 Gerion — Tang Primer 25K HDMI AUDIO reference check

**Purpose:** test an **additional complete third-party .fs** known to ship in an explicit HDMI sound release. Our only verified external VIDEO+AUDIO Board PASS so far is A2600Nano v2.5. PR25-08/09/10 video worked but **all audio tests remained silent**.

- Author/repository: [Papr1ka/brus16](https://github.com/Papr1ka/brus16).
- Exact release: [sfx / Sound update firmware](https://github.com/Papr1ka/brus16/releases/tag/sfx), published **2026-07-13**.
- Original `tp25k.zip`: [direct download](https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip), **4,214,200 bytes**.
- **Official GitHub asset digest** (verified against Release API metadata): `SHA256 a8c0e4e096656b89d8b74c4929abbe8d601da996e1ac6d2b1f78480a8a270e69`.
- The upstream release announces **“Sound is implemented over HDMI”**, and names **gerion (Sound!!!)**.
- FPGA: Tang Primer 25K (GW5A-25A); PMOD DVI on original pin group H5/J5, H8/H7, G7/G8, F5/G5.
- RTL original: `src/brus16_top.sv` -> `sfx_top` (44.1kHz) -> `hdmi.sv` -> `ELVDS_OBUF`; Gowin project includes TP25K-specific PLL and constraints. No SDRAM is needed for the **individual embedded-game image**; other peripherals may be needed to interact with the game.
- No source HDL, PiKoSoL or configuration Flash is modified by this test.

## Status and limitation

**Operator board-tested: VIDEO PASS / AUDIO NOT HEARD.** Original Gerion and all the other operator-tested .fs images in the same Brus-16 SFX archive produced HDMI video. The operator reported **no audible audio in any of them**. This does not prove that each game generated nonzero audio; Gerion is the documented meaningful audio-negative case because its source calls `play_song(song)` at the title screen. The verified-download script remains for repeatability; do **not** continue the same batch of tests solely to find another image.

## Operator commands — PowerShell 7

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/ThirdParty/Brus16-SFX"
& .\Tang-Primer-25K\ThirdParty\Brus16-SFX\Run_Brus16_Gerion.ps1
```

This performs **download, source validation, ZIP entry inventory, Gerion .fs extraction and SHA256 report ONLY**, with no FPGA programming. Look at the reported Gerion entry name.

To load this exact extracted firmware to **FPGA SRAM only**:

```powershell
& .\Tang-Primer-25K\ThirdParty\Brus16-SFX\Run_Brus16_Gerion.ps1 -Program
```

Uses the **identical known-working Gowin Programmer command** from PR25-08:
`programmer_cli.exe --device GW5A-25A --cable-index 1 --run 2 --fsFile <full-path-to-gerion.fs>`.

**Do not use Flash programming commands. Do not write the ZIP to an SD card.**

The script saves local `firmware/gerion.fs`, `evidence/BRUS16_*_MANIFEST.json` and transcript logs. These are excluded by `.gitignore` and should not be committed.


## Multi-firmware selector — ALL TESTED IMAGES VIDEO, NO AUDIBLE AUDIO

**Operator observation (2026-11-14):** the original Brus-16 SFX `Gerion` bitstream displays VIDEO on our Primer 25K, but **no audible audio** was heard. This is **VIDEO BOARD PASS / AUDIO FAIL**, not a full HDMI/audio success. The original A2600Nano v2.5 remains our only confirmed HDMI VIDEO + AUDIO BOARD PASS. The Gerion game's original [`gerion.py`](https://github.com/true-grue/Brus-16/blob/main/games/gerion/gerion.py) calls `play_song(song)` while `TITLE_MODE` is set, so the game title is expected to create PCM, even without gamepad input; that does not prove that a particular binary was generated from that exact source revision.

You can now enumerate, select and repeatedly SRAM-program **any** released `.fs` from the verified official `tp25k.zip` via one script. The archive is checked against its official SHA256 every time; no external Flash, SD card or BL616 writes.

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/ThirdParty/Brus16-SFX"

# List all original .fs names without changing FPGA
& .\Tang-Primer-25K\ThirdParty\Brus16-SFX\Select_Brus16_SFX.ps1

# Interactive: enter number, observe display/sound, continue to next
& .\Tang-Primer-25K\ThirdParty\Brus16-SFX\Select_Brus16_SFX.ps1 -Program
```

For a named candidate, use `-Game gerion -Program` or `-Game pong -Program`, if the archive contains a unique matching filename; the script lists the actual entries and refuses ambiguous matching. Each run saves a JSON receipt and operator transcript under `evidence/`. **An `.fs` for a game with no audio code is not a valid negative audio test.** Of the game source files inspected, Gerion explicitly invokes `play_song`, `sfx_start`, and `sfx_mix`; Pong does not have such calls in its inspected source. Silence in Pong therefore cannot disprove functioning HDMI audio.

### New technical investigation: audio rate coherence, not yet confirmed cause

At the original `sfx` tag, TP25K PLL configuration declares `Clkout0ExpectedFrequency=125` MHz and its `CLKDIV /5` would nominally produce **25.0 MHz**, while `sfx_controller.sv` was designed around **25.2 MHz / 571.4286 = 44,100 samples/s**, and `hdmi.sv` declares the `640×480` pixel rate as **25.2 MHz** for ACR calculations. Thus if the actual hardware clock is 25.0 MHz, the generated audio sample clock is approximately **43,750 Hz**, a **−0.794%** difference from nominal. Do not conclude this is the cause of silence until the PLL configuration and actual sample clock are verified at the board; a 0.8% mismatch alone does not establish a loss of all audio. More generally, changing a different game `.fs` does **not** fix a common HDMI timing issue if all bitstreams came from the same build settings.

Reference: [Brus-16 `sfx` source tree](https://github.com/Papr1ka/brus16/tree/sfx), [`sfx_controller.sv`](https://github.com/Papr1ka/brus16/blob/sfx/src/sfx/sfx_controller.sv), [TP25K PLL configuration](https://github.com/Papr1ka/brus16/blob/sfx/gowin/src/tp25k/gowin_pll/gowin_pll.ipc).

## Observations to record

| Check | Result |
| --- | --- |
| ZIP size SHA-256 matches official release | Archive accepted by programmed-image script; standalone verification log not provided in chat |
| Archive contains Gerion .fs | Used in board trial; actual ZIP member name not quoted |
| Gowin Programmer exit 0 (SRAM) | VIDEO observed; actual CLI exit log not provided |
| HDMI monitor displays Gerion | **BOARD VIDEO PASS — operator-confirmed** |
| HDMI monitor displays other .fs images in SFX archive | **VIDEO PASS — operator reports all tested files working** |
| **Audible audio in Brus-16 images** | **FAIL — operator heard none** |
| A2600Nano v2.5 VIDEO + AUDIO | **BOARD PASS — separate known-good control** |

A game menu or splash screen does **not** mean sound works: gameplay may require controller/button input. The script cannot add a controller that is not present. Report the exact operator observations without inventing audio PASS.

If this Gerion image cannot generate sound autonomously in the current setup, try independent VIC20Nano/NanoApple2 TP25K firmware only with their respective MCU/SD requirements understood; do not call those immediately plug-and-play.

See [research record](../../../ip/hdmi/BRUS16_TP25K_AUDIO_CANDIDATE_RU.md) for source comparison.

## Closeout after full SFX firmware batch (14 Nov 2026)

The operator confirmed: **every tested original Brus-16 SFX firmware displays video, none has audible audio**. Stop repeatedly switching images; they share the same HDMI output implementation. Do not infer that games without music generate audio. Gerion's `TITLE_MODE` path explicitly requests music in the upstream game source, but we have no per-FS PCM waveform trace.

Comparative source check: Brus-16 `src/hdmi/hdmi.sv` is the hdl-util family, `VIDEO_ID_CODE=1` (640x480) with nominal `VIDEO_RATE=25.2 MHz` and `AUDIO_RATE=44100`; its SFX PLL .ipc nominal fast clock is 125 MHz, divided by five. The original **working** A2600Nano `src/hdmi/hdmi.sv` is a **modified derivative** accepting `stmode`, `cea`, `total_lines` and `screen`; it receives `audio_sample_word({audio_vol_l,audio_vol_r})` via `src/misc/video.v`, with `AUDIO_RATE=48000`. Thus `Brus16` and A2600 are not independent unrelated HDMI codec families. The existence of the Gerion music code and the author's sound release claim does not prove compatibility with our display/sink at the exact tested timing.

**Engineering decision:** no third iteration of a synthetic tone or game firmware sweep. Preserve golden A2600Nano v2.5 .fs. Next investigate / reproduce its **entire known-good video.v + HDMI + PLL + mode source + reset / serializer integration**, starting with a byte-identical source build, then alter the **audio sample source alone** while keeping the rest constant. A build is not an audio pass until audible board confirmation. Alternate hypothesis: monitor treats some timing/metadata configurations as video-only; this is unproven and requires sink format/status information or controlled test.
