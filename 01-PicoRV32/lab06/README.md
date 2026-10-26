# LAB-06.2A — PicoRV32 minimal native SoC, Tang Nano 9K

**Status 2026-10-26: LAB-06.2A real PicoRV32 SIM PASS (attested by verified SIM receipt); LAB-06.2B Gowin PnR PASS and exact bitstream produced. Internal Setup/Hold screen PASS, but Recovery/Removal NOT REPORTED (STA FAIL/INCOMPLETE). BankVccio of fitted ports NOT AUDITED. BOARD NOT RUN; DO NOT PROGRAM.**

A separate reference SoC for later controlled comparison with NEORV32 LAB-06.1 (which is already BOARD BASIC PASS). Nothing under LAB-04, Pong, RetroStation or the accepted NEORV32 bitstream is modified.

- Real pinned PicoRV32: `ef203c2b0a3fb793280f5114941416c425c5b461`, ISC upstream.
- RV32I `-march=rv32i -mabi=ilp32`, GCC `-Os`, no M/C/IRQ/performance counters.
- 27 MHz, 16 KiB on-chip boot ROM, 2 KiB RAM, separate PicoRV32 UART TX/RX, six LEDs.
- FPGA I/O pinout will be matched to the accepted LAB-06.1 at later FIT stage.
- First functional firmware: `PICORV32 READY\r\n` (16 bytes), GPIO `0x15` to `0x2A`. NEORV32 initial banner is 15 bytes, so **not a throughput comparison**.
- This is a **native-SoC** trial, not a bare-CPU area comparison. The UART and MMIO are different hardware from NEORV32 native peripherals, and no equal-workload W01/W02/W03 benchmark has run.

## LAB-06.2B checkpoint — 2026-10-26 17:47, PnR PASS / STA INCOMPLETE

**Operator-provided actual PowerShell/Gowin evidence (no inference from hypothetical logs):**

- Matched upstream CPU PicoRV32 `ef203c2b0a3fb793280f5114941416c425c5b461`; new SIM-PASS receipt `lab06/_build/run_20261026_174737_806/receipt.json` is validated by `fit_lab062.ps1` and ROM hash.
- Exact PnR job: `01-PicoRV32/lab06/_build/fit_20261026_174759_839_3ed614`.
- Actual 16KiB ROM SHA256: `694CF644C770382518371DF4382013AAFEDB6CFEEFC87F6CA15A140BA2F2478B`. RAM 2KiB; clock 27MHz; RV32I; UART+6 LEDs.
- Fitted but NOT hardware-authorized `lab062_pico_nano9k.fs` SHA256: `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`.
- PnR resource summary: logic **1500/8640 (18%)**, registers **551/6693 (9%)**, **BSRAM 54%**, DSP 0%, PLL 0%, IO 10.
- Setup/Hold: `1794` paths, `1530` endpoints; 0 Setup violations, 0 Hold violations; minimum Setup **+16.325 ns**, Hold **+0.427 ns**.
- `Recovery Paths Table` and `Removal Paths Table` numeric slacks were **not found** by the current STA parser: `{'recovery': None, 'removal': None}`. It is **not correct** to replace this with zero, positive slack, or mark full STA PASS. The `fit_lab062.ps1` correctly ended with `LAB062_STA_SCREEN_FAIL: DO NOT PROGRAM`, even though a physical `.fs` file was produced.
- This PicoRV32 RTL actually has external asynchronous reset `always @(posedge clk_i or negedge rstn_i)`. Recovery/Removal are timing checks for asynchronous reset release; the current single-line SDC only defines the 27MHz clock. We must inspect the *actual* Gowin report to distinguish no analyzed paths from a parser limitation. Keep a separate external-reset/IO timing caveat.
- Preliminary SoC comparison: PicoRV32 1500 logic, 551 registers, BSRAM54% vs NEORV32 3228 logic, 1923 registers, BSRAM20%. **These are total native SoCs, not bare CPU area, and differ in peripheral implementation, ROM inference and UART banner length.** No claim of performance advantage or equal memory-mapping efficiency yet.

### NEXT: read-only diagnostics; NO more synthesis and NO programming

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 01-PicoRV32/lab06/tools/diagnose_fit_lab062.py 01-PicoRV32/lab06/README.md
.\02-NEORV32\tools\activate_ucrt64.ps1
python .\01-PicoRV32\lab06\tools\diagnose_fit_lab062.py `
  '.\01-PicoRV32\lab06\_build\fit_20261026_174759_839_3ed614' `
  --expected-sha '31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0'
```

This script **only reads** the existing bitstream, STA HTML, PnR resources and 10 pin/BankVccio rows; it has no Gowin/USB/FPGA programming actions. It prints the first useful Recovery/Removal section content and BSRAM evidence, but deliberately **does not** issue STA PASS. On its output, decide whether a justified N/A classification or reset/SDC correction is needed. Do not waive missing async checks by changing the auditor alone. For resource comparison, inspect actual inferred ROM/BSRAM mapping before drawing conclusions.

## Control point 2026-10-26 17:19 — first PicoRV32 SIM blocked by testbench CR literal

The operator ran `tools/run_lab062.ps1 -Mode Sim`. Output:

- Source pin `ef203c2b0a3fb793280f5114941416c425c5b461` — PASS.
- Job `01-PicoRV32/lab06/_build/run_20261026_171900_218`.
- Actual RV32I binary `140 bytes`; SHA256 `6AB802C371F1100F40635019C4306B44DF04E572B51F0070DA4C9AA0808415F6`.
- ROM `16384 bytes`; SHA256 `694CF644C770382518371DF4382013AAFEDB6CFEEFC87F6CA15A140BA2F2478B`.
- Icarus/VVP ran the real pinned CPU and checked UART bytes `0..13`, then rejected byte `14`: `got=0d wanted=72`.
- The **firmware emitted the correct CR byte `0x0D`** after `PICORV32 READY`, but the original Verilog testbench specified `"PICORV32 READY\r\n"`. Icarus treated Verilog `\r` as literal ASCII `r` (0x72). This is a **testbench oracle defect**, not evidence of a bad CPU/UART output. Byte `15` (LF) and final GPIO pattern were not yet checked.
- Fix in **testbench only**: `localparam [LEN*8-1:0] EXPECT={"PICORV32 READY",8'h0D,8'h0A};`. Explicit 14 printable ASCII bytes + 0x0D + 0x0A = 16 UART bytes. No firmware, ROM, RTL, linker, Gowin or device change.
- **SIM status still NOT PASS** until another real operator Icarus run completes all UART bytes and both LED patterns; original `vvp.log` should be retained in ignored `_build`. No programming or FPGA access.

### Next exact command (PowerShell 7, no new board action)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 01-PicoRV32/lab06/tests/tb_lab062_pico.v 01-PicoRV32/lab06/README.md
.\02-NEORV32\tools\activate_ucrt64.ps1
.\01-PicoRV32\lab06\tools\run_lab062.ps1 -Mode Sim
```

Desired *future* `LAB062_PICORV32_UART_GPIO_TB_PASS` and `LAB062_SIM_PASS`. If the next failure is at **LED final state**, inspect the actual UART frame completion handshaking, not the testbench's CR/LF escape. All LAB-04, accepted NEORV32 and PicoRV32 upstream sources remain untouched.

## Next operation — only functional simulation

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- 01-PicoRV32/lab06
.\01-PicoRV32\tools\fetch_picorv32.ps1
.\02-NEORV32\tools\activate_ucrt64.ps1
.\01-PicoRV32\lab06\tools\run_lab062.ps1 -Mode Sim
```

Required **future**, not yet observed, results: `LAB062_SOURCE_PIN_PASS`, `LAB062_FW_IMAGE_PASS`, `LAB062_ROM_IMAGE_PASS`, `LAB062_PICORV32_UART_GPIO_TB_PASS`, `LAB062_SIM_PASS`.

The script builds a real freestanding RISC-V firmware using the operator's UCRT64 cross compiler, generates a deterministic ROM hex, stages actual CPU and UART RTL in unique ignored `_build/run_*`, runs Icarus Verilog/vvp, checks real bit-level UART and both physical LED patterns, then creates SHA manifest and receipt. Nothing is written to FPGA/Flash/SD.

After SIM PASS: create isolated Gowin FIT and STA report with correct 3.3V clock bank and compare resources **only as full native SoC**. Do not compare against old PiKoSoL+HDMI resource utilization.
