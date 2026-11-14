# PR25-11 — untouched original A2600Nano v2.5 source build (HDMI AUDIO A/B)

**Status: PREPARED; Gowin build & rebuilt board NOT YET TESTED.** The original author-published A2600Nano v2.5 FPGA bitstream was confirmed by the operator as **HDMI VIDEO+AUDIO BOARD PASS**. PR25-08..10 and the tested Brus-16 SFX images delivered video, not audible audio.

## Verified original reference

- Repo: https://github.com/MiSTle-Dev/A2600Nano
- Tag: `v2.5`, exact commit `705bf787675579721d339806cb522905dec73ed3`
- Original build recipe: https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/build_tp25k.tcl — `GW5A-LV25MG121NC1/I0`, `A2600_top`, *all original* RTL/CST/SDC and Gowin IP.
- Original downloadable Golden: https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs
- Golden size **4,700,888 bytes**, official GitHub release SHA256 `531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff`.
- Author's `build_all.bat` uses **Gowin 1.9.12.02**, while operator has **Gowin 1.9.9Beta-4 Education**. This matters: original RTL does not imply an identical compiled image across tool versions.

## Zero-modification workflow

`Build_Original.ps1` clones the complete pinned tag, verifies full SHA and clean tracked source, creates an isolated `git archive` export and executes **upstream's own `build_tp25k.tcl` without changing one source file**. Logs and SHA256 manifest are kept locally. If the build fails, an old success manifest cannot authorize programming. It does **not** program FPGA.

`Program_SRAM.ps1` has two explicit choices: `-Variant Golden` downloads/verifies and loads the author .fs, `-Variant Rebuilt` loads only a successful manifest-verified local rebuild. Both use the previously verified Gowin `--device GW5A-25A --cable-index 1 --run 2 --fsFile` — **volatile SRAM only**, never external Flash.

Run in PowerShell 7 from the root of local `C:\GitHub\Sipeed-FPGA`:

```powershell
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/Examples/PR25-11-A2600-ORIGINAL-REBUILD"

# A. Original release current-session video+audio control
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Program_SRAM.ps1 -Variant Golden

# B. Compile exact upstream source; do not program if build/STA fails
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Build_Original.ps1

# C. After BUILD PASS + STA review, test rebuilt firmware in SRAM
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Program_SRAM.ps1 -Variant Rebuilt

# Return to author Golden at any time
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Program_SRAM.ps1 -Variant Golden
```

## Record observations carefully

| GOLDEN | REBUILT | Implication |
| --- | --- | --- |
| Picture + sound | Picture + sound | **Rebuilt AUDIO BOARD PASS**. Basis for a future *one-change* PCM source replacement |
| Picture + sound | Picture, no sound | Difference in compiler/implementation/peripheral state — inspect Gowin report and compare builds, keep Golden unchanged |
| Picture + sound | No picture | PLL/constraints/toolchain failure — revert |
| Picture, no sound | Any | Old audio success not reproducible with current monitor/MCU/SD/game configuration; fix that control first |
| Any | Build error | Do not program rebuilt .fs; inspect first tool error |

**Crucial hardware note:** the author's [Tang Primer 25K setup](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/TANG_PRIMER_25K.md) uses an M0S Dock companion MCU via PMOD adapter and PMOD TF-CARD for normal games. The scripts do not provide these peripherals. To compare audibility, reproduce **the same game/audio content and connected peripherals** as during the previously audible Golden test; an idle menu may not generate PCM.

**Audio implementation:** A2600's `src/misc/video.v` passes signed 16-bit stereo PCM to modified `src/hdmi/hdmi.sv` at declared 48kHz, including Audio Sample, ACR, and InfoFrame. Brus-16 source has HDMI `DVI_OUTPUT=0` and an SFX path at 44.1kHz, but the release binaries were silent on the operator's display. A working TMDS picture does **not** prove audio.

The scripts are the only project-owned files. Upstream source, output `.fs`, build workspaces, SHA manifests and logs are local and ignored by Git.
