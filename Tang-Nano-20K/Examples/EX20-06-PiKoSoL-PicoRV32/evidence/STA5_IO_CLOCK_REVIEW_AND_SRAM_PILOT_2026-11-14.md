# EX20-06: STA-5 pin/clock review; controlled SRAM pilot

**Review evidence:** operator's direct PowerShell excerpt from candidate `candidate_20261114_062849_118` on 2026-11-14.

## Final STA-5 pin report and routing

- Fitted `reset_btn` pin **88 / bank 3** (`IOR30[A]`) reports **LVCMOS33**, **PULL_MODE=DOWN**, **SINGLE_RESISTOR=ON**, `BankVccio=3.3`. This resolves the prior incorrect 1.2 V assignment *in the Gowin fitted pin report*. The 3.3-V assignment is consistent with [the official Sipeed HDMI CST](https://github.com/sipeed/TangNano-20K-example/blob/main/hdmi/src/hdmi.cst).
- The same candidate's PnR `rpt.txt` section `6. Global Clock Signals` states `clk27_d | PRIMARY | TR TL BR BL`; `pix_clk | PRIMARY | TR TL BR BL`; `serial_clk | HCLK | BOTTOM[0]`.
- `gowin.log` line 163 still reports `PR1014`: `Generic routing resource will be used to clock signal 'clk27_d' by the specified constraint. And then it may lead to the excessive delay or skew`. The clock summary does NOT prove the entire pin-to-global-buffer feeder avoids generic interconnect. This warning is **NOT cleared** and must remain a hardware risk caveat for the board trial.
- STA-5 gate (operator log) showed zero setup/hold violations and zero TNS in CPU, pixel and serial domains; setup +0.387 ns, hold +0.208 ns, recovery +12.116 ns, removal +0.925 ns; pixel Fmax 100.363 MHz, six first-stage CDC exceptions active. Source head `80395e6`; SHA256 `.fs` `1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2`; 7,264,150 bytes.

## Pilot decision

**Experimental SRAM-only pilot MAY BE ATTEMPTED with controlled safeguards. It is not full electrical/timing/functional certification, and no flash programming is authorized.** The positive timing fit and known-good Tang Nano 20K LiteX/Sipeed pin reference are adequate to *attempt* the low-risk nonpersistent trial while observing PR1014 and the vendor PLL/DVI IP limitations. The existing factory flash image remains the recovery path.

A new guard script `tools/sram_pilot.ps1` uses exact `.fs` SHA and length, STA gate JSON, fitted pin 88 report and PnR global clock report. By default it performs **checks and JTAG scan only**. Actual SRAM programming is gated behind both explicit `-Program` and exact human confirmation `GW2AR-18C SRAM ONLY` after reading scan output. It uses the previously hardware-confirmed Gowin CLI `programmer_cli.exe --device GW2AR-18C --run 2 --fsFile ... --cable-index 1`. Do not enable other run modes. Close serial terminal / other JTAG clients first; inspect scan for **one GW2AR-18C**, ID `0x0000081B`. Stop on unknown devices.

### Operator sequence

1. Fetch/update clean tracked source worktree; run `python .\tests\test_contract.py` (12/12) and optional `.\tests\run_sim.ps1` for confirmation. Rebuilding is **not needed**; guard matches the existing candidate.
2. **Read-only preflight**: from EX20-06 run `.\tools\sram_pilot.ps1` and inspect console JTAG scan output. Stop if device identity or any local evidence differs.
3. **Opt-in programming**: if and only if user decides to test, run `.\tools\sram_pilot.ps1 -Program`, inspect its scan again, type the exact confirmation phrase, and confirm Gowin SRAM command exit 0.
4. Reopen COM25 115200 8N1; inspect `PiKoSoL>` and `HELP`, HDMI full 1280x720 160x60 text, GFX eight objects, LED commands, reset/PLL reacquire. Distinguish source-ROM boot from actually observed UART and HDMI. Preserve full transcript and photos.
5. Power-cycle to confirm factory boot from Flash still works. Do not flash or perform destructive SD writes. Record observations as **BOARD PARTIAL / PASS / FAIL** on each exercised subsystem, not a blanket pass.

**Known gaps:** no validated full-raster pixel timing simulation with encrypted vendor DVI IP; CDC bundled-data first-stage exceptions are deliberately narrowly waived; residual PR1014 clock feeder warning. Do not claim native 720p picture, UART shell, LEDs or eight hardware objects without operator results.
