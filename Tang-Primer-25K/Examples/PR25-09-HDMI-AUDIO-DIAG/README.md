# PR25-09 — HDMI AUDIO diagnostic on Tang Primer 25K

**Purpose:** isolate HDMI audio failure observed on [PR25-08](../PR25-08-HDMI-AUDIO-GOLDEN/README.md), which has **BOARD VIDEO PASS** but **no audible tone**. This is a NEW experiment. PR25-08 and working A2600Nano v2.5 source remain unchanged.

**Status: SOURCE PREPARED — BUILD NOT RUN — BOARD NOT TESTED.**
The original A2600Nano v2.5 full system produced both picture and sound on the user's physical board. The new PR25-09 is not yet proven.

## What is held constant

- The same proven 50 MHz E2 clock, upstream v2.5 PLL / PLL_INIT, qualified LOCK, Gowin CLKDIV /5
- Upstream unmodified HDMI packet modules, serializer `OSER10` and four `ELVDS_OBUF`
- Same PMOD DVI connector (USB-A side), exact P/N pins and HDMI video geometry: 912x524 / 720x480
- No CPU, SDRAM, SD card, external keyboard, ROM image or PiKoSoL modification

## What changed from PR25-08

- Audio waveform generated in the **audio sample clock domain** and packed into HDMI using upstream's preferred `audio_sample_word({audio_l, audio_r})` form.
- ~1000 Hz stereo square wave at ±0x3000 (moderate level), alternating about **0.75 s ON / 0.25 s OFF**.
- A small on-screen marker at top-left changes **green during ON, red during silence**, independently indicating that the audio test generator is running. This does **not** show whether HDMI audio packets reach the monitor.
- The PMOD, clock and video timing are unchanged. The marker is the only intended picture alteration.
- The nominal HDMI ACR/audio rate metadata remains **48 kHz** as upstream; this run does not validate an exact sample-clock frequency. Do not infer sound success from build alone.

## Build and test

From PowerShell 7, in the local repository checkout:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- `
  "Tang-Primer-25K/Examples/PR25-09-HDMI-AUDIO-DIAG" `
  "ip/hdmi/a2600nano-primer25k"
& .\Tang-Primer-25K\Examples\PR25-09-HDMI-AUDIO-DIAG\Build_HDMI_AUDIO.ps1
```

Inspect Gowin exit status, timing report (setup/hold), fresh generated `impl/pnr/pr25_hdmi_audio_diag.fs` and SHA256. **Do not program on a failed build or failed STA.** Then (FPGA **SRAM only**, no Flash):

```powershell
& .\Tang-Primer-25K\Examples\PR25-09-HDMI-AUDIO-DIAG\Program_SRAM.ps1
```

Expected observation: 8 color bars / center line and green/red blinking marker ~once per second, with a matching intermittent audible stereo beep. If there is still no audio, record whether the monitor shows an HDMI audio input format; continue analysis of ACR/InfoFrame/data-island and exact 48 kHz clock before changing the encoder.

## Acceptance

| Check | Status |
|---|---|
| PR25-08 original independent VIDEO | BOARD PASS |
| A2600Nano v2.5 original VIDEO + AUDIO | BOARD PASS |
| PR25-09 Gowin build + STA | OPEN |
| PR25-09 SRAM programming | OPEN |
| PR25-09 video color bars and changing activity marker | OPEN |
| PR25-09 audible beep 0.75s on/0.25s off | OPEN |
| PR25-09 audio format recognized by monitor | OPEN |

Note: upstream code and modified integrations are subject to GNU GPL-3.0 and original copyright notices. The HDL wrappers were written specifically for this experiment, not as a replacement for the original HDMI IP reference.
