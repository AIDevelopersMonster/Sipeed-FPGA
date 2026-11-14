# PR25-13 — SDC clock waveform 50% hypothesis (A2600Nano TP25K)

**STATUS: SOURCE PASS + BUILD PASS (Gowin 1.9.9, EXIT 0); GLOBAL SETUP/HOLD = 0/0; SELECTED NEGATIVE RECOVERY PATHS = 0; PROGRAM ATTEMPT BLOCKED BY JTAG CABLE OPEN FAILED (EXIT 50). NO VIDEO/AUDIO BOARD RESULT. TA1123 PERSISTS.** This is a controlled experiment on top of PR25-12, **not** a confirmed FPGA/HDMI fix.

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


## Operator BUILD PASS — 15 Nov 2026 01:09:49

**Observed:** exact source `705bf787675579721d339806cb522905dec73ed3`; Gowin target `GW5A-25A / GW5A-LV25MG121NC1/I0`; final **EXIT 0**; generated `artifacts/a2600nano_tp25k_SDC50.fs`; **SHA256 `22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a`**. `Negative Recovery paths selected: 0`, compared with three negative Recovery paths in PR25-12. FPGA was **not programmed** (Golden still working).

- Confirmed edited SDC: `clk_pixel_x5 -period 6.984 -waveform {0 1}` changed to `{0 3.492}` in isolated copy. Full actual PLL waveform is not yet measured. SHA256 original `25987a1fd3438169c05d715a673165b10d9553d070b6281f40b1191e3d84b619`; patched `6c276448928f8b857158f2d77ce22dae271391406963ba8b2a110d4755e35060`.
- PR25-13 source `serializer.sv` modified SHA differs from PR25-12 because the code-injected **experiment comment** says `PR25-13` rather than `PR25-12`. The inserted reset synchronizer RTL logic is identical. This minor text difference may still change placement/build provenance; only timing/board evidence can validate equivalence.
- Gowin **`TA1123` persists:** `clk_pixel_x5` frequency does not match `mainclock/u_pll/PLLA_inst/CLKOUT0`.
- Additional **`TA1117` clock-relationship warnings** persist for `rLockOut`, `clk`, `clk_audio`, `clk_cpu`, `mcu_spi_inst/n4_24`.
- Synthesis **`NL0002`** swept module hierarchy for `audio_info_frame`, `audio_sample_packet`, `auxiliary_video_information_info_frame` and `source_product_description_info_frame`. Do **not** assume the HDMI packets disappeared merely from a hierarchy optimization warning: inspect synthesized netlist/outputs, particularly if HDMI video works but audio is missing.
- Preliminary **PLL frequency computation from upstream static parameters** in `gowin_pll_ntsc_mod.vhd`: `FCLKIN=50MHz`, `IDIV_SEL=2`, `FBDIV_SEL=1`, `MDIV_SEL=53`, `ODIV0_SEL=9`, `ODIV0_FRAC_SEL=2` (1/8 steps), internal feedback. Formula from Gowin UG306: `F_static ≈ 50/2*1*53/(9+2/8) = 143.243243 MHz`; independently `1 / 6.984ns = 143.184422 MHz`. Difference ≈ **0.058822 MHz (0.041%)**. **Important:** a separate `PLL_INIT` module dynamically writes PLL registers, so this static estimate does not establish the actual **post-initialization** clock or prove the sole reason for TA1123. See [Gowin UG306](https://cdn.gowinsemi.com.cn/UG306E.pdf).

**Unresolved:** global `Numbers of Setup Violated Endpoints`, global Hold, any Removal violations, full clock model and hardware operation. These metrics are not present in the pasted final build lines. The '0 negative Recovery' print covers only selected paths from the Gowin HTML table, not every clock/cross-clock path. Therefore STATUS is NOT STA PASS.

### One read-only summary command (PowerShell 7)

```powershell
$pr = ".\Tang-Primer-25K\Examples\PR25-13-A2600-SDC-DUTY50"
$m = Get-Content "$pr\artifacts\sdc50_manifest.json" -Raw | ConvertFrom-Json
$h = Get-Content (Join-Path $m.workspace "impl\pnr\a2600nano_tp25k_tr_content.html") -Raw
[regex]::Matches($h, '(?is)<td[^>]*>\s*(Numbers of (?:Setup|Hold) Violated Endpoints)\s*</td>\s*<td[^>]*>\s*(\d+)\s*</td>') | ForEach-Object {
    "{0} = {1}" -f $_.Groups[1].Value, $_.Groups[2].Value
}
```

If this prints zero global Setup and Hold, it still does **not** imply a valid physical waveform or close CDC/Recovery paths; review `TA1123/TA1117` and cross-clock paths before experimental SRAM programming. The officially downloaded Golden is the verified hardware baseline.


## Operator STA global counters — 15 Nov 2026 (PR25-13)

Operator read the exact PR25-13 generated `a2600nano_tp25k_tr_content.html` and extracted:

```
Numbers of Setup Violated Endpoints = 0
Numbers of Hold Violated Endpoints = 0
```

Together with `Negative Recovery paths selected: 0`, this supports **experimental SRAM-only board testing** (not production acceptance). It does not prove all cross-clock paths were constrained, removal timing closed, a physical 50% PLL clock, or resolution of `TA1123` (PLL/SDC frequency mismatch) and `TA1117` (unknown interclock relationships). **Never claim FULL STA PASS** from the two counters alone.

**Next controlled board A/B:** program the existing PR25-13 `artifacts/a2600nano_tp25k_SDC50.fs` using `Program_SRAM.ps1 -Program` **only when ready to briefly overwrite current FPGA SRAM configuration**. Observe image and audible sound in same game/cable/monitor configuration as Golden. If no video/audio, restore PR25-11 `Program_SRAM.ps1 -Variant Golden` and record the board failure. Do not program nonvolatile Flash or modify MCU. Avoid further RTL/SDC tweaks before recording the A/B result.


## SRAM cable open error — operator evidence, 15 Nov 2026 01:21

Operator executed `Program_SRAM.ps1 -Program` with **validated** PR25-13 .fs SHA256 `22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a`; Gowin Programmer selected **FT2CH cable index 1** and target `GW5A-25A(0x0001281B)`, but printed:

```
Operation "SRAM Program" for device#1...
Error: Cable open failed
SRAM PROGRAM EXIT: 50
```

Evidence: `evidence/PR25_13_SRAM_20261115_012146631.txt` on operator PC. **This is a USB-JTAG cable/driver/open error, before programming succeeded. It is not BOARD FAIL or BOARD PASS.** The requested device name in the output is not an independently successful JTAG scan. No evidence of SRAM overwrite. Known working original Golden should remain unless the board was subsequently changed/reset.

The PR25-13 script and the previously successfully used PR25-11 Golden script both specify identical `--device GW5A-25A --cable-index 1 --run 2 --fsFile ...` flags; only image path differs. Per [Gowin Programmer User Guide SUG502](https://cdn.gowinsemi.com.cn/SUG502E.pdf), cable-index 1 selects FT2CH and `programmer_cli.exe --scan` scans the device. Sipeed's [FAQ](https://wiki.sipeed.com/hardware/en/tang/common-doc/questions.html) identifies `Cable open failed` as debugger/cable detection error. Recovery: close competing Gowin Programmer GUI/IDE and other processes accessing FTDI; replug programming USB cable if needed. Before any FPGA write run a **read-only** scan:

```powershell
$cli = "C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe"
& $cli --scan --cable-index 1
```

Only if a real scan detects GW5A-25A should operator retry the PR25-13 `Program_SRAM.ps1 -Program`. **Do not switch to an unverified cable index or Flash mode.**


## Operator monitor observation (15 Nov 2026)

After the attempted PR25-13 SRAM test the operator reported **no working HDMI picture or audio**, but observed the monitor briefly change **black → grey → black**. This is an observable display transition, **not a video/audio board PASS**. The only console transcript supplied for the PR25-13 SRAM operation has `Cable open failed` / `SRAM PROGRAM EXIT: 50`, which **does not establish that the PR25-13 bitstream was loaded**; no later successful `EXIT 0` was supplied. Thus the grey flash is not yet evidence of PR25-13 TMDS output, PLL lock, or HDMI link negotiation. Preserve Golden as known-good control. **Before interpreting a board fail, first verify successful cable opening and SRAM program EXIT 0.** Do not alter RTL/SDC or flash as a consequence of this ambiguous observation.
