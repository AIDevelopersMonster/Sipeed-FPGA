# PR25-13 — SDC clock waveform 50% hypothesis (A2600Nano TP25K)

**STATUS: SOURCE PREPARED; BUILD NOT RUN, BOARD NOT TESTED.** This is a controlled experiment on top of PR25-12, **not** a confirmed FPGA/HDMI fix.

## Grounded evidence from operator on 15 Nov 2026

- PR25-11 original v2.5 recompiled with Gowin 1.9.9Beta-4: **BUILD PASS but VIDEO FAIL + AUDIO FAIL**. Official Golden v2.5 restored VIDEO + AUDIO immediately.
- PR25-11 STA detected three negative Recovery paths at Gowin `OSER10` reset pins, **−2.505 ns** each, sourced from `video_analyzer/vreset` in `clk`.
- PR25-12 modified only the RESET connection with 3-stage x5 clock recovery synchronizer. **BUILD PASS / SHA256 `70a9a314de58239676f4fcb181c7da40bbe7cafbe553e27411f5a02282679e4a`.** Hardware NOT tested.
- PR25-12 still reports three **negative Recovery** paths: `gwSer0/RESET = −1.309 ns`, `gwSer1/RESET = −1.155 ns`, `gwSer2/RESET = −0.994 ns`. All launch from `oser_reset_pipe_2_s1/Q` on `clk_pixel_x5:[R]` and are checked against `clk_pixel_x5:[F]`, with **`Relation 1.000 ns`**.
- PR25-12 Gowin warns `TA1123: clock clk_pixel_x5 frequency does not match ... PLLA_inst/CLKOUT0` and `TA1117` for several derived clocks. Those warnings require further investigation and cannot be cleared by a cosmetic SDC edit.

## The single controlled change relative to PR25-12

The upstream A2600Nano v2.5 SDC says:

```tcl
create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 1} [get_nets {clk_pixel_x5}] -add
```

This instructs STA to treat the falling edge as **1.000 ns** after rising edge despite the period being **6.984 ns**. Assuming a nominal 50% duty at the PLL clock output, the more plausible falling edge is **3.492 ns** after the rise:

```tcl
create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 3.492} [get_nets {clk_pixel_x5}] -add
```

The test changes this **one SDC line in an isolated build export**, without changing PR25-12 synchronizer RTL, video, audio, PLL VHDL, Gowin primitive instantiation or pin constraints. The same `-loading_rate 70.000` Tcl compatibility omission is reused from PR25-11 and PR25-12. Both original and modified SDC SHA256s are recorded in the manifest. The **physical** clock duty cycle and exact PLL frequency have not been measured, so 50% is an **assumption** requiring validation. Positive STA slack after this change would prove only that **this constraint model** does not show a Recovery violation—not that the original hardware problem was fixed. This is NOT an accepted STA constraint correction until PLL clock and half-period timing are verified.

## Operator command — BUILD ONLY, NO FLASH

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin main
git restore --source FETCH_HEAD --worktree -- "Tang-Primer-25K/Examples/PR25-13-A2600-SDC-DUTY50"
& .\Tang-Primer-25K\Examples\PR25-13-A2600-SDC-DUTY50\Build_SDC50.ps1
```

Stop after the build. Report `GOWIN EXIT`, all **negative Recovery paths**, any `TA1123` PLL warning, and global setup/hold count. **DO NOT PROGRAM UNTIL STA REVIEW.** A clean Recovery result cannot be fabricated by modifying only constraints; verify actual physical clocks, ideally under the author's original Gowin 1.9.12.02.

The optional `Program_SRAM.ps1 -Program` is provided for a *later* explicitly authorized SRAM-only test, not for immediate use. Revert to known-good Golden at any time using `PR25-11...\Program_SRAM.ps1 -Variant Golden`.

## Interpretation

- If Recovery becomes positive while `TA1123` persists, the original negative Recovery was at least partly due to the SDC waveform model; PLL frequency consistency and real board functionality still remain OPEN.
- If Recovery remains negative, test a serializer reset release synchronized to the **actual OSER10 recovery edge** in an isolated RTL variant or use Gowin 1.9.12.02.
- If the build otherwise fails or violations shift into other paths, STOP and review the detailed report.

Nothing here changes PR25-08..12, the official A2600 Golden, external Flash, BL616, SD card or PiKoSoL.
