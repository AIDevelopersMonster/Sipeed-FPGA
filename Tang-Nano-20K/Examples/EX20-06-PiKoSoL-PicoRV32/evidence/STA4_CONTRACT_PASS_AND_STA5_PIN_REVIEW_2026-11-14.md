# PiKoSoL 20K — STA-4 static PASS and STA-5 pin 88 review

**Operator evidence:** Windows PowerShell on feature branch commit 5241a4e. `python .\tests\test_contract.py` printed `Ran 12 tests in 0.005s; OK`. The two prior Icarus simulations had both printed PASS. This is a **static/source check PASS**, not a new board validation.

**STA-4:** source revision 306c72e, candidate `candidate_20261114_035245_996`. Gowin STA gate EXIT=0; setup/hold violated endpoints 0/0; per-clock TNS all 0; Fmax pixel 100.363 MHz against 74.25; setup first listed +0.387 ns, hold +0.208, recovery +12.116, removal +0.925. Bitstream SHA256 `A8CCA71A7658E100B0EF9EEFDD4F3274FEB601180C7F2294F903F21304DA49F0`. The preceding STA-4 source is a fixed evidence snapshot; do NOT relabel the resulting bitstream as STA-5.

## Source-grounded IO discrepancy

The previously uploaded STA-2 PnR `pikosol20k_picorv32_candidate.pin.html` pin report has:
- `reset_btn` **pin 88 / bank 3**, `LVCMOS33`, `PULL_MODE=DOWN`, **BankVccio=1.2** V.
- `clk27` pin 4: `LVCMOS33`, BankVccio 3.3 V.
- `uart_rx` pin 70 / `uart_tx` pin 69: 3.3 V.
- LED pins 15-20: 3.3 V.
- HDMI differential pins 33-40: LVDS25, 2.5 V.

The official Sipeed [hdmi/src/hdmi.cst](https://github.com/sipeed/TangNano-20K-example/blob/main/hdmi/src/hdmi.cst) declares `I_rst` pin 88 with `LVCMOS33 PULL_MODE=DOWN SINGLE_RESISTOR=ON BANK_VCCIO=3.3`. The [LiteX platform](https://github.com/litex-hub/litex-boards/blob/master/litex_boards/platforms/sipeed_tang_nano_20k.py) also declares pin 88 `LVCMOS33`.

**STA-5 isolated CST experiment:** constrain `reset_btn` pin 88 explicitly to `LVCMOS33 PULL_MODE=DOWN SINGLE_RESISTOR=ON BANK_VCCIO=3.3`; preserve CPU, 720p, terminal, eight objects, SDC and reset RTL unchanged. An accompanying static test prevents regressing this rule. Gowin build and PnR need rerun to verify whether the BankVccio warning disappears and all STA checks remain PASS. **Do not assume setting an SDC/CST parameter changes physical bank hardware voltage.**

## Remaining clock-route warning

STA-2 `gowin.log` warns `PR1014`: `Generic routing resource will be used to clock signal 'clk27_d' by the specified constraint. And then it may lead to the excessive delay or skew`. Its full PnR `rpt.html` Global Clock Signals labels `clk27_d` as PRIMARY in regions TR TL BR BL, and serial_clk/pix_clk also use global resources. A warning is not by itself a demonstrated malfunction, but the affected route/clock-tree and actual WNS must be reviewed. Do not suppress PR1014 without grounding.

## Acceptance after STA-5

Run static 12 tests; Icarus renderer and reset; Gowin build; `collect_sta.ps1`. Inspect the **new** `pin.html` directly: pin 88 `BankVccio=3.3` (not 1.2), no other IO bank changed unexpectedly; verify full STA, six CDC exceptions, `PR1014` clock report, reproducible source revision and new .fs checksum. If pin 88 stays 1.2, stop for device/pin-bank manufacturer documentation. Only then plan **SRAM-only** board test; never use Flash programming.

Current status: **STA-4 PASS, STA-5 NOT RUN ON GOWIN, BOARD NOT TESTED.**
