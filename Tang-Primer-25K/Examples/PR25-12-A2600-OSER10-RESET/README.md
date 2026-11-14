# PR25-12 — A2600Nano v2.5 / OSER10 Recovery timing experiment

**Status: SOURCE PREPARED — NO BUILD OR BOARD TEST PERFORMED.** Previous original A2600Nano v2.5 rebuilt with Gowin 1.9.9Beta-4 produced `.fs` with EXIT 0 but **no HDMI video or audio**. The unchanged official v2.5 release restored both. The 2026-11-15 operator report found **3 negative Recovery paths** (each **−2.505 ns**), all to the three Gowin OSER10 `RESET` pins. All 25 explicitly requested `Setup Paths` were positive and the per-clock TNS was zero.

## Direct upstream source trace

1. [video_analyzer.v](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/misc/video_analyzer.v) generates `vreset` in the `clk` pixel-clock domain; its `changed` detection sends an intermittent one-cycle reset to align HDMI timing with the game.
2. [video.v](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/misc/video.v) wires `hdmi.reset(vreset)`. The HDMI module uses the reset for frame counters **and** passes it directly to `serializer.reset`.
3. [serializer.sv](https://github.com/MiSTle-Dev/A2600Nano/blob/v2.5/src/hdmi/serializer.sv) wires the signal to **three OSER10 `.RESET(reset)`** on GW5A. Each OSER10 has `PCLK(clk_pixel)`, `FCLK(clk_pixel_x5)`; the active-high RESET pin is **asynchronous** according to Gowin UG289.
4. The operator's generated report traced precisely these three paths:
   `video_inst/video_analyzer/vreset_s0/Q (clk:[R]) -> video_inst/hdmi/serializer/gwSer{0,1,2}/RESET (clk_pixel_x5:[F])`, each with **Recovery Slack −2.505 ns**.

**This proves a Recovery timing violation, not that the violation alone caused the complete no-video/no-audio board failure.** The original author-release GOLDEN works despite having the same RTL; different Gowin place-and-route and PLL implementations remain independent hypotheses.

Gowin UG289 documentation: https://cdn.gowinsemi.com.cn/UG289E.pdf ; Gowin SUG940 Timing: https://cdn.gowinsemi.com.cn/SUG940E.pdf .

## Controlled change (separate test branch)

`Build_ResetSync.ps1` exports the exact upstream tag `v2.5` / `705bf787675579721d339806cb522905dec73ed3`. It patches only `src/hdmi/serializer.sv` inside an isolated work directory:
- leave all original video frame reset, TMDS encoder, HDMI audio packets, PLL/CLKDIV, pins, hardware IP and game logic unchanged;
- add a three-stage **asynchronously asserted, x5-clock-synchronously released** active-high serializer reset;
- replace only the three Gowin OSER10 `.RESET(reset)` with `.RESET(oser_reset_x5)`;
- retain exactly the **same single Gowin 1.9.9 TCL compatibility adjustment** as PR25-11: omitting unsupported `set_option -loading_rate 70.000` from an isolated TCL copy.

This is one controlled RTL delta relative to the PR25-11 rebuilt case, **not an upstream correction or a guaranteed fix**. Since a release on rising FCLK could still violate Recovery to FCLK falling edge depending on routed delay, the build must be independently rechecked for `Recovery`, `Removal`, `Setup`, `Hold` and PLL lock issues; no timing PASS is presumed.

## Operator procedure (PowerShell 7)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/Examples/PR25-12-A2600-OSER10-RESET"
& .\Tang-Primer-25K\Examples\PR25-12-A2600-OSER10-RESET\Build_ResetSync.ps1
```

**STOP at the build result.** Do not program this image until we inspect the new timing report to see whether the three Recovery violations disappeared without creating new violations. If acceptable, the dedicated manual SRAM-only program script is:

```powershell
& .\Tang-Primer-25K\Examples\PR25-12-A2600-OSER10-RESET\Program_SRAM.ps1 -Program
```

If experimental hardware fails, restore official known-audible Golden (from PR25-11):

```powershell
& .\Tang-Primer-25K\Examples\PR25-11-A2600-ORIGINAL-REBUILD\Program_SRAM.ps1 -Variant Golden
```

No programming of Flash, BL616, SD or PiKoSoL. No changes are made to PR25-11 original/rebuilt images or any upstream tracked source.
