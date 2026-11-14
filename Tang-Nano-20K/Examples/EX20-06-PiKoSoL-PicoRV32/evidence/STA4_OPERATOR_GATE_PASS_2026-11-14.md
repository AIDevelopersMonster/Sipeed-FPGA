# EX20-06 PiKoSoL 20K — STA-4 operator evidence (2026-11-14)

**Status: TIMING-GATE PASS; IO/CLOCK/SRAM BOARD REVIEW PENDING. This is NOT BOARD PASS.**

Operator PowerShell log `Вставленный текст(20261114-005529).txt`, source revision `306c72e`, candidate `candidate_20261114_035245_996`; Gowin completed synthesis, PnR and STA. Reported metrics:

| Metric | Result |
|---|---:|
| Pixel Fmax / required | **100.363 / 74.250 MHz** |
| Setup WNS (first listed path) | **+0.387 ns** |
| Hold WNS | **+0.208 ns** |
| Recovery WNS | **+12.116 ns** |
| Removal WNS | **+0.925 ns** |
| Global Setup/Hold violated endpoints | **0 / 0** |
| clk27, pix_clk, fast PLL setup/hold TNS | **0.000 ns** for all six rows |
| Active scoped CDC exceptions | **6/6** |
| STA gate | **EXIT=0; PASS_FOR_IO_REVIEW_NOT_BOARD** |
| Bytecode bitstream size | **7,264,150 bytes** |
| SHA256 of generated bitstream | **A8CCA71A7658E100B0EF9EEFDD4F3274FEB601180C7F2294F903F21304DA49F0** |

**RTL simulation:** `PIKOSOL20K_RENDERER_PIPELINE_SIM_PASS` and `PIKOSOL20K_RESET_SIM_PASS` from Windows Icarus. **Static tests were 11/12, not 12/12:** source-change stale assertion expected `always @(posedge serial_clk or negedge raw_good)` in reset controller, which was intentionally removed when vendor HDMI reset became `PLL LOCK && !reset_btn`. Corrected source-contract assertion in GitHub revision `909c143` (separate from generated bitstream). Retest static tests to confirm 12/12. Contract-only revision does not affect generated hardware bits.

**Still blocked before any SRAM board operation:**

1. Clock route warning `PR1014` for `clk27_d` (need full log context, origin, clock-tree report and assessment).
2. Pin bank electrical audit. Existing `pikosol20k.cst` marks reset pin 88 `LVCMOS33` without explicit `BANK_VCCIO`; prior report showed `BankVccio 1.2`. Sipeed official 20K `hdmi/src/hdmi.cst` has FPGA pin 88 LVCMOS33, `BANK_VCCIO=3.3`; LiteX platform also declares pin 88 LVCMOS33. This supports intended 3.3 V but does NOT independently prove the generated pin report is electrically correct. Compare actual STA-4 `pin.html`, bank assignments and official board electrical schematic before changing CST or programming.
3. Review reset behavior with real PLL/DVI IP (encrypted, not covered by Icarus), and CDC bundled-data handshakes. Synthesis STA signoff covers constrained timing paths; not hardware functionality.
4. File .fs has a SHA from operator, not uploaded binary. Preserve it and do not publish as independently board-proven firmware.

**Factory Flash remains untouched.** No auto-programming is included in build or analysis scripts. No SRAM programming until separate board IO/clock review.
