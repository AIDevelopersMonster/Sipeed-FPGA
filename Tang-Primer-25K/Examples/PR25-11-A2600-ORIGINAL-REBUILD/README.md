# PR25-11 — untouched original A2600Nano v2.5 source build (HDMI AUDIO A/B)

**Status: SOURCE PASS + BUILD PASS (Gowin EXIT 0, 2026-11-14 23:27:38); STA NOT REVIEWED; REBUILT AUDIO BOARD NOT TESTED.** The original author-published A2600Nano v2.5 FPGA bitstream was confirmed by the operator as **HDMI VIDEO+AUDIO BOARD PASS**. PR25-08..10 and the tested Brus-16 SFX images delivered video, not audible audio.

## Verified original reference

- Repo: https://github.com/MiSTle-Dev/A2600Nano
- Tag: `v2.5`, exact commit `705bf787675579721d339806cb522905dec73ed3`
- Original build recipe: https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/build_tp25k.tcl — `GW5A-LV25MG121NC1/I0`, `A2600_top`, *all original* RTL/CST/SDC and Gowin IP.
- Original downloadable Golden: https://github.com/MiSTle-Dev/A2600Nano/releases/download/v2.5/a2600nano_tp25k.fs
- Golden size **4,700,888 bytes**, official GitHub release SHA256 `531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff`.
- Author's `build_all.bat` uses **Gowin 1.9.12.02**, while operator has **Gowin 1.9.9Beta-4 Education**. This matters: original RTL does not imply an identical compiled image across tool versions.

## Zero-RTL-modification workflow

`Build_Original.ps1` clones the complete pinned tag, verifies full SHA and clean tracked source, creates an isolated `git archive` export and executes **upstream's own `build_tp25k.tcl` first without changes**. On the exact error `invalid loading_rate value`, it creates a **second** TCL copy `build_tp25k_compat199.tcl` with only the unsupported `set_option -loading_rate 70.000` line commented out, then retries. The original TCL, RTL, FPGA IP, PLL, pins and SDC are untouched. Logs and SHA256 for both TCL versions are recorded. Logs and SHA256 manifest are kept locally. If the build fails, an old success manifest cannot authorize programming. It does **not** program FPGA.

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


## Compatibility incident — operator log 2026-11-14 23:09

Golden `Program_SRAM.ps1 -Variant Golden` exited **0**, proving only successful SRAM programming; the operator did not specify in this log whether audio was audible again. Original source clone matched the exact `v2.5` SHA `705bf787675579721d339806cb522905dec73ed3`. Gowin stopped on line 65 of the author's `build_tp25k.tcl`: `invalid loading_rate value` for `set_option -loading_rate 70.000`. **Synthesis did not start; no new .fs was generated.** Loading rate is FPGA configuration speed, not HDMI audio sample rate.

The updated build runner retries only for this exact error, from a separate compatibility TCL and with all upstream HDL untouched. Re-run **only** the build after fetching this update:

```powershell
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Build_Original.ps1
```

Do not program the rebuilt .fs unless the new build succeeds and STA setup/hold is checked. The original Golden file and the FPGA configuration currently loaded from it are not modified by the build.

## BUILD PASS — operator report, 2026-11-14 23:27:38

- Build driver used: `build_tp25k_compat199.tcl` (only unsupported `set_option -loading_rate 70.000` omitted from a temporary Tcl copy).
- Gowin result: **final EXIT 0**, compiled author original RTL, HDMI modules, PLL, IP and board constraints.
- New independent bitstream: `artifacts/a2600nano_tp25k_REBUILT.fs`.
- SHA256: `8d4c22cc08e66d4397cf2cf90f0400b36679c1ed84386d250ace63b0dca460fa`.
- Build log: `evidence/PR25_11_COMPAT199_20261114_232526889.log`.
- Manifest: `artifacts/rebuild_manifest.json`.
- **STA setup/hold not reviewed**, no board observation of the new bitstream yet; NOT Audio Board PASS.
- Official source release GOLDEN SHA256 remains `531b786061cc3b428d829e9f445787d20c6f847645031e3a0a57f64d58ba4aff`; a different SHA for a separately compiled build under Gowin 1.9.9 is not itself evidence of error.

### Minimal read-only timing report inventory (PowerShell)

```powershell
$pr = ".\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD"
$m = Get-Content "$pr\artifacts\rebuild_manifest.json" -Raw | ConvertFrom-Json
$pnr = Join-Path $m.workspace "impl\pnr"
Get-ChildItem -LiteralPath $pnr -Recurse -File |
  Where-Object { $_.Name -match '(?i)(tr_content|timing|sta|\.rpt$|_tr\.)' } |
  Select-Object Name, Length, FullName
```

Review actual **setup/hold slack, violating paths, clocks** in the reported file(s) (typically `*_tr_content.html`) or Gowin Timing Analyzer; the list alone is NOT a timing pass. Do not run `Program_SRAM.ps1 -Variant Rebuilt` until reports have been reviewed. FPGA SRAM-only Golden restore remains available.
