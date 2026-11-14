# PR25-10 — HDMI AUDIO PACKET PROBE (Tang Primer 25K)

**Purpose:** investigate the confirmed **PR25-08 VIDEO PASS / AUDIO FAIL** and **PR25-09 video and red/green tone marker PASS / AUDIO FAIL**, reported by the hardware operator on 2026-11-14.

**Status:** sources prepared; **NOT BUILT, NOT BOARD TESTED**.

This experiment retains the same known-good PLL/CLKDIV/OSER10/ELVDS output, HDMI video timings and PMOD pins. The untouched A2600Nano v2.5 IP snapshot stays in `ip/hdmi/a2600nano-primer25k/vendor` and the working PR25-08/PR25-09 directories are not modified.

## What changed

1. New `rtl/probe/hdmi_probe.sv`, `packet_picker_probe.sv` and `audio_clock_regeneration_packet_probe.sv` derived from the original GPL-3.0 sources with additional debug outputs; these are separate copies, not changes to upstream.
2. `audio_clock_regeneration_packet_probe.sv`: add initial `= 1'b0` to `clk_audio_counter_wrap` so ACR wrap toggle is defined at FPGA configuration. The source in upstream did not explicitly initialize this bit. **This is a hypothesis, not a proven cause.**
3. Display five **sticky** status flags in upper-left screen area; red means not yet observed, green means observed since HDMI reset. A sixth, lower status marker changes red/green with the 0.75s/0.25s tone envelope, as in PR25-09.
4. Keep audio clock divider, PCM tone amplitude, video geometry, serializer and entire physical output fixed.

## Five indicators (left-to-right)

| Flag | Turns GREEN when | Interpretation |
| --- | --- | --- |
| D0 | `packet_enable` | HDMI Data Island scheduler has packet slots |
| D1 | `sample_buffer_ready` | Four stereo PCM samples have formed a buffer |
| D2 | `sample_buffer_ready` is selected at `packet_enable` | Audio Sample Packet **scheduled** |
| D3 | ACR wrap is selected at `packet_enable` | Audio Clock Regeneration Packet **scheduled** |
| D4 | `!audio_info_frame_sent` is selected at `packet_enable` | Audio InfoFrame **scheduled** |

These are internal **scheduling** indicators, not hardware probing of the serialized TMDS wires and not HDMI sink acknowledgment. Green flags alone do not prove the monitor recognizes the audio or audio packets are standards-compliant.

## Operator procedure (PowerShell 7)

Fetch the test and original IP into the local checkout:

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- `
  "Tang-Primer-25K/Examples/PR25-10-HDMI-AUDIO-PACKET-PROBE" `
  "ip/hdmi/a2600nano-primer25k"
```

Build without touching FPGA, and inspect Gowin setup/hold timing reports:

```powershell
& .\Tang-Primer-25K\Examples\PR25-10-HDMI-AUDIO-PACKET-PROBE\Build_HDMI_AUDIO.ps1
```

If fresh `.fs` and acceptable timing are obtained, load **SRAM only**:

```powershell
& .\Tang-Primer-25K\Examples\PR25-10-HDMI-AUDIO-PACKET-PROBE\Program_SRAM.ps1
```

Reduce monitor audio volume initially; test tone is deliberately audible in this diagnostic.

Report a simple observation: **image yes/no; D0..D4 red or green; lower tone envelope marker alternates yes/no; sound yes/no**. The five flags should normally become green if the scheduler is functioning; failing flags identify a narrower source of trouble.

To restore working VIDEO-only PR25-08:
```powershell
& .\Tang-Primer-25K\Examples\PR25-08-HDMI-AUDIO-GOLDEN\Program_SRAM.ps1
```

## Next diagnosis depending on flags

- D0 red: no packet slots; inspect timing/data-island activation.
- D0 green, D1 red: audio sample buffer is not filling; inspect sample clock, clock-crossing and port binding.
- D0,D1 green but D2 red: sample scheduling is starved or incorrectly prioritized.
- D3 red: ACR not scheduled despite defined initial wrap; inspect clock or ACR scheduling.
- All green with no sound: inspect **actual packet contents/CRC and the sink's reported audio format**, as the status only proves internal decisions; no more speculative volume increases.

This source uses upstream GPL-3.0 code in the instrumented copies; preserve their copyright notices and GPL conditions.
