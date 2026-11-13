# EX20-06: STA-3 operator receipt and STA-4 vendor reset hypothesis

## Operator-reported STA-3 (2026-11-14; source head 09d130d)

- Static contracts 12/12 PASS, Icarus renderer PASS, Icarus reset PASS.
- Gowin PnR and bitstream generation completed, candidate `candidate_20261114_011112_194`.
- Generated `.fs` 7,264,150 bytes, SHA256 `0B216F95DF3017C880BF40036853B8339B55FFA61C991B0A62DD937F895F0390`. **DO NOT PROGRAM**, timing gate failed.
- Pixel domain Fmax **102.964 MHz** versus required **74.25 MHz**.
- Setup path-list first slack +0.112 ns, but global tool summary **77 setup violated endpoints**.
- Per-clock setup TNS: `clk27` 0.000, `pix_clk` 0.000, high-speed PLL 371.25 MHz **−2.690 ns, four endpoints**.
- Hold count 0, worst listed slack +0.228 ns; Recovery **−0.672 ns**; Removal +0.914 ns.
- All six narrow CDC exceptions active. `PR1014` generic clock routing persists.
- `STA_GATE_EXIT=2`, `FAIL_DO_NOT_PROGRAM`.

The operator prepared `EX20-06_STA_candidate_20261114_011112_194.zip`. This exact new archive is not yet independently parsed here; detailed endpoint identity is inferred from prior STA-2 reports and the changed RTL only, not proven from the STA-3 full report. The `−2.690 ns` TNS and four endpoints remain **blocking**.

## Vendor reference and STA-4 hypothesis

The official [Sipeed Tang Nano 20K HDMI video_top.v](https://github.com/sipeed/TangNano-20K-example/blob/main/hdmi/src/video_top.v) explicitly wires `hdmi4_rst_n = I_rst_n & pll_lock` to both `CLKDIV.RESETN` and `DVI_TX_Top.I_rst_n`. It uses no FPGA fabric shift register at 371.25 MHz to deassert the vendor IP's reset.

Previous STA-3 `u_reset/ser_release_2_s1/Q` was such a high-speed shift-register output used as async reset for `OSER10`. The earlier full STA-2 archive showed its Recovery paths to `OSER10_{clk,b}/RESET` with −0.672 ns (falling fast clock) and −1.168 ns (pixel-clock relation); the STA-3 printed worst Recovery is −0.672 ns. Thus **STA-4 replaces the serializer reset source with `pll_locked && !reset_btn`, as the upstream vendor example does**.

CPU and pixel domains continue to assert reset asynchronously on PLL loss or button and to deassert in their own domains. No new false-path or clock-group exceptions were introduced. This is a controlled, source-grounded reset topology experiment, **not** a proof that PLL lock inherently meets arbitrary async release timing inside encrypted IP.

## Required reproduction

Update isolated worktree to latest feature branch without deleting or overwriting untracked build artifacts. Run contract tests and both Icarus simulations, then Gowin `build.ps1` and `tools/collect_sta.ps1`. Compare all per-clock TNS, global violations, recovery/removal, six CDC exception states and `PR1014`. Capture newest ZIP. **Even an automated STA PASS is not board authorization** until full reset strategy, IO bank configuration (pin 88 VCCIO mismatch) and generic clock routing are independently checked. Do not program FPGA SRAM or Flash yet.
