# EX20-06 — STA-2 forensic paths and STA-3 controlled experiment

**Source:** uploaded `EX20-06_STA_candidate_20261113_203153_718(1).zip`, built 2026-11-13 20:32 (Gowin V1.9.9 Beta-4 Education, GW2AR-LV18QN88C8/I7). RTL at STA-2 build was predecessor `922b901` with a reserved identifier later fixed in `591914d`. The build was successful but **STA_GATE FAIL / DO NOT PROGRAM**.

## Exact totals; reconcile misleading first-path WNS

- Overall tool summary: **9,283 paths analyzed / 9,155 endpoints**, **97 setup violated endpoints**, **0 hold violations**.
- Per-domain **TNS**:
  - `clk27`: setup 0.000 ns, 0 endpoints; hold 0.000 ns.
  - `pix_clk`: setup 0.000 ns, 0 endpoints; hold 0.000 ns.
  - PLL high-speed `u_pll/rpll_inst/CLKOUT.default_gen_clk` (371.25 MHz): **setup TNS −2.690 ns, 4 endpoints**; hold 0.000 ns.
- Clock Fmax: `clk27` **79.324 MHz** versus 27; `pix_clk` **104.546 MHz** versus 74.25; PLL fast clock **1238.659 MHz** versus 371.25 (local data paths, not a complete serializer reset qualification).
- The first *listed* 25 setup paths are all positive; first **+0.205 ns** crosses a bundled-data mailbox `u_scene/u_byte_cdc/char_hold_sys_6_s0/Q` → `event_byte_6_s0/D` (`clk27` → `pix_clk`). The 25 printed paths do **not** include the failing 4 PLL endpoints. A positive first printed path cannot overrule the summary. The global count 97 and per-domain count 4 use different aggregation; do **not** claim 97 separate pixel-pipeline failures.

## Recovery paths from original report

1. **−2.403 ns**: `u_reset/ser_release_2_s1/Q` (PLL serial clock 371.25 MHz) → `u_reset/por_count_15_s0/PRESET` (27 MHz). The same source drives most of the CPU `por_count` 16 FFs and `cpu_release` async resets.
2. **−1.713 ns**: same serial release → `u_reset/pixel_release_0_s1/CLEAR` (pixel clock).
3. HDMI primitive `OSER10` asynchronous reset violations still present: **−0.672 ns** for serial-to-opposite serial clock edge and **−1.168 ns** versus pixel clock. These are not waived and are not guaranteed fixed by the STA-3 change.

**Cause and intervention:** STA-2 used `sys_raw_good = raw_good && resetn_serializer` and `pixel_raw_good = resetn_serializer && resetn_cpu`. These carried the *fast-domain registered release* as an asynchronous reset across unrelated clocks. STA-3 changes CPU and pixel async assertion sources to independent `raw_good = pll_locked && !reset_btn`. CPU and pixel reset deassertion is still synchronized to each clock domain; `CLKDIV` and DVI serializer continue using `resetn_serializer`. The precise impact on recovery and timing **must be confirmed by new Gowin STA**, and independent HDMI `OSER10` recovery is still an open blocker.

## Other findings and safeguards

- `PR1014`: `clk27_d` uses generic clock routing; not accepted as fully closed.
- Pin report: **reset_btn at FPGA pin 88 / bank 3**, `IO_TYPE LVCMOS33` but inferred `BankVccio=1.2` V. Electrical correctness is **unverified** and BLOCKS board connection/programming until reconciled with official board documentation/constraints.
- BSRAM synthesis is retained, no `IF0008`, no `EX3988`. Bitstream was produced but is NOT qualified; candidate `.fs` SHA256 `2ACB8186264EDA9C4B17AE491DD11A18C5569B7593B7F9462B3A9CBAAF934B43` (size 7,264,150 bytes).
- Six narrowly targeted first-stage CDC exceptions are all `Actived`. The bundled-data mailbox still requires independent CDC protocol verification; do not false-path entire clock groups.
- STA gate changed to include *all per-clock TNS rows and violated endpoint counts*, not merely the first listed setup path; it continues to fail closed if any 97 global violations remain.

## Reproduction, in order

1. Update the isolated worktree only if there are no tracked local changes.
2. Run `python .\tests\test_contract.py` and `.\tests\run_sim.ps1`. **Do not proceed on failures**.
3. After both pass, run `.\build.ps1`, then `.\tools\collect_sta.ps1`.
4. Inspect recovery path names, global 97 count and per-clock TNS after STA-3. Further address any remaining `OSER10` violations **without blind timing exceptions**, plus pin-88 electrical mismatch and `PR1014`.
5. No SRAM/Flash programming and no BOARD PASS until a separately reviewed bitstream/STA/IO signoff.

**Caveat:** updated STA-3 reset RTL and gate have not yet been compiled/re-synthesized by Gowin; this is a targeted hypothesis backed by STA-2 path evidence, not a claimed timing fix PASS.
