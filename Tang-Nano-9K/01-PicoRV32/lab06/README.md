# LAB-06.2A — PicoRV32 minimal native SoC, Tang Nano 9K

**Status 2026-10-27: LAB-06.2A PicoRV32 real-CPU SIM PASS, LAB-06.2B Gowin PnR PASS, internal Setup/Hold 0 violations, fitted pins/BankVccio 10/10, LAB-06.2C BOARD BASIC PASS: exact Pico image loaded to volatile SRAM, UART byte-exact 16/16, and operator observed 3 LEDs lit. Recovery/Removal `Nothing to report!`; async-reset release not timing-qualified. Core-only and equal-workload CPU performance benchmarks remain NOT RUN; no Flash/SD writes.**

A separate reference SoC for later controlled comparison with NEORV32 LAB-06.1 (which is already BOARD BASIC PASS). Nothing under LAB-04, Pong, RetroStation or the accepted NEORV32 bitstream is modified.

- Real pinned PicoRV32: `ef203c2b0a3fb793280f5114941416c425c5b461`, ISC upstream.
- RV32I `-march=rv32i -mabi=ilp32`, GCC `-Os`, no M/C/IRQ/performance counters.
- 27 MHz, 16 KiB on-chip boot ROM, 2 KiB RAM, separate PicoRV32 UART TX/RX, six LEDs.
- FPGA I/O pinout will be matched to the accepted LAB-06.1 at later FIT stage.
- First functional firmware: `PICORV32 READY\r\n` (16 bytes), GPIO `0x15` to `0x2A`. NEORV32 initial banner is 15 bytes, so **not a throughput comparison**.
- This is a **native-SoC** trial, not a bare-CPU area comparison. The UART and MMIO are different hardware from NEORV32 native peripherals, and no equal-workload W01/W02/W03 benchmark has run.

## 2026-10-27 — LAB-06.2C PicoRV32 physical board acceptance (BASIC PASS)

**Actual board measurements, operator-supplied and recorded verbatim in the acceptance:** [LAB062_BOARD_2026-10-27.md](acceptance/LAB062_BOARD_2026-10-27.md).

- **Actual image:** `lab062_pico_nano9k.fs` (not KBlocks), SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`, pinned PicoRV32 core `ef203c2b0a3fb793280f5114941416c425c5b461`.
- **FPGA SRAM load:** `Programming... 100%`, user code `0x0000B310`, status `0x0003F020`, cost `4.59s`; the exact SHA was already verified by the smoke runner before programming. No Flash, SD or permanent configuration writes.
- **Physical CPU activity:** UART COM10 115200/8N1 captured **16 exact bytes**: `b'PICORV32 READY\r\n'`, `LAB062_UART_BANNER_PASS`; S1 reset requested during capture. This proves the executed RV32I boot test in combination with prior real-CPU simulation and source-pin evidence, not full ISA compliance.
- **GPIO:** operator: **three LEDs are lit**. Exact physical 6-bit LED mask/order not independently measured; expected logical mask at end of firmware is `0x2A`.
- **Acceptance level:** **BOARD BASIC PASS**, not full async reset signoff, CPU-only performance/area audit, repeated reset reliability, UART RX test, or W01/W02/W03 benchmark. Prior failed FT2CH cable open and accidental KBlocks load remain preserved as *historical* checkpoints below.

We now have separate NEORV32 and PicoRV32 physical basic passes on the same Sipeed Tang Nano 9K. Next work is a common measured RV32I workload (W01) plus resource/memory inference audit, without rebuilding this accepted bring-up image merely to change logging.

## Control point — 2026-10-27: Programmer functional again, but loaded KBlocks (not LAB-06 Pico)

**Operator evidence (PowerShell command and Gowin output):** the existing `program_lab04_sram.ps1 -Bitstream $Fs -Program` command completed `SRAM Program` 100% with status `0x0003F020`, user code `0x0000F9C8`, cost 3.65s, Gowin FT2CH interface, FPGA GW1NR-9C. **The actual printed `BITSTREAM:` is from a different repository:** `C:\GitHub\KonSol-RetroStation\games\kblocks-rgb\build\20261026_125847\work\impl\pnr\konsol_kblocks_rgb_nano9k.fs`, SHA256 `F842B196CB4A56E0C18DEF1C471CBDDC82F59F0B552A27F553FDFF9692BBDC4E`.

This is strong evidence that the **Gowin USB/JTAG cable works now**, at least for the KBlocks programming operation. It is **NOT** LAB-06 PicoRV32 BOARD PASS and does not demonstrate a successful SRAM load of the Pico candidate. The PowerShell session variable `$Fs` pointed to KBlocks at invocation; it must not be reused across projects without rechecking. We cannot infer precisely why the prior `Cable open failed` happened.

**Exact pending Pico candidate**, unchanged: `01-PicoRV32\lab06\_build\fit_20261026_174759_839_3ed614\lab062_pico_nano9k.fs`, SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`.

**Safe next experiment:** resolve this *specific* relative file to a new variable `$PicoFs`, verify full SHA256 and leaf filename `lab062_pico_nano9k.fs`, then invoke the existing SRAM-only programmer with `-Bitstream $PicoFs -Program` (not `$Fs`). Observe `PICORV32 READY` via UART 115200 8N1 and three illuminated LEDs; do not claim PASS until actual board evidence. Maximum 2–3 documented board attempts; no extra RTL rebuild, Flash or SD. Async reset recovery/removal remains not characterized.

## LAB-06.2C — First SRAM attempt BLOCKED BY USB/JTAG CABLE, 2026-10-26

Operator verified the exact `lab062_pico_nano9k.fs` SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0` in PowerShell. The known-good SRAM programmer wrapper reported `LAB04_SRAM_DRY_RUN_ONLY` on the first invocation, so nothing was written. Explicit `-Program` invocation then reported:

```text
OPERATION: GW1NR-9C, operation_index 2, volatile SRAM (not Flash)
Target Cable: Gowin USB Cable(FT2CH)/0/0/null@2.5MHz
Target Device: GW1NR-9C(0x1100481B)
Operation "SRAM Program" for device#1...
Error: Cable open failed
Cost 0.0 second(s)
Gowin Programmer failed with exit code 50
```

**Interpretation:** JTAG cable/driver/access failure before FPGA programming, **not** a PicoRV32 firmware, RTL, PnR or bitstream hash failure. The device text in this CLI message is not proof that the USB hardware was opened successfully. Hardware UART/LED tests cannot yet begin, and there was no SRAM rewrite. Prior NEORV32 on this board **did** program successfully using FT2CH.

**Two-step bounded diagnostic (Windows CLI, no Flash):**
1. Close all COM/serial monitors, WebSerial/WebUSB tabs, Gowin Programmer GUI / other JTAG programs. If a PowerShell `$sp` serial object from the earlier terminal exists, close and dispose it. Inspect present FTDI/COM/JTAG devices using `Get-PnpDevice -PresentOnly`. If USB unplug/replug is needed, note SRAM contents will be lost.
2. Run read-only programmer scan: `C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe --scan --cable-index 1`. Only if the actual physical FPGA is enumerated, repeat **one** SHA-verified SRAM-only `-Program`. If scan fails, stop instead of retry loops; examine FTDI interface A/B driver binding, cable, USB socket, and possible JTAG enable S2 per Sipeed guide. Changing FPGA RTL or remaking ROM has no demonstrated benefit.

Official Sipeed FAQ explicitly lists `Cable open failed` as debugger detection / programmer problem: https://wiki.sipeed.com/hardware/en/tang/common-doc/questions.html

**Status:** `LAB062_CABLE_OPEN_FAILED`; `LAB062_BOARD_NOT_CONFIGURED`; GPU/CPU performance comparison `NOT RUN`. STA async-reset caveat remains separate and unresolved.

## LAB-06.2B checkpoint — final read-only PnR diagnostics / bounded SRAM test decision (2026-10-26)

**Observed operator output of `diagnose_fit_lab062.py` for exact existing candidate** `_build/fit_20261026_174759_839_3ed614`:

- `LAB062_EXISTING_FIT_SHA256_PASS` for SHA256 `31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0`. The previous fit already validated the real PicoRV32 SIM PASS receipt, checked the 16KiB ROM hash and all pinned RTL hashes.
- Internal STA paths `1794`, endpoints `1530`; Setup violations `0`, Hold violations `0`; Setup slack `+16.325ns`, Hold slack `+0.427ns`.
- Gowin reported clock period `37.037ns` / `27.000MHz`, **estimated Fmax `48.281MHz`** (PnR timing estimate only; not hardware-clock proof).
- `Recovery Paths Table` and `Removal Paths Table` both contain the explicit `Nothing to report!`. In Gowin's documentation this means **no paths to analyze for those categories**, not an evaluated positive slack or zero violations. Because Pico has asynchronous reset `rstn_i`, **async reset deassertion timing remains NOT QUALIFIED**. No manual false-path exceptions were detected in the report. FULL STA SIGNOFF = **NO**. External UART RX/RESET timing not characterized by the clock-only SDC.
- **Ten fitted I/O port rows match expected** pins, IO types, and VCCIO. Clock pin52 bank1 `LVCMOS33/3.3`; UART pin17/18 bank2 `LVCMOS33/3.3`; reset pin3 and LED pins10/11/13/14/15/16 bank3 `LVCMOS18/1.8`.
- Resources: Logic `1500/8640 (18%)`, Registers `551/6693 (9%)`, BSRAM `54%` (`SDPB 2` listed); DSP `0`, PLL `0`, I/O `10`. **54% BSRAM cannot be assigned solely to CPU or ROM from the summary**. The actual ROM is 16KiB with NOP padding, binary 140B, RAM 2KiB; compare actual mapped primitives before concluding a core-level memory penalty.
- **Decision (bounded smoke):** this exact SHA is eligible for a **single volatile-SRAM-only experimental load** using known-good Tang Nano 9K hardware and the existing LAB-04 programmer wrapper. This does **not** replace FULL STA sign-off: reset-release can occasionally fail near a clock edge. An initial power-on programming result is accepted only with real UART boot and actual LEDs. The operator should open the UART first and use S1 reset if the boot banner is missed. If reset/boot is unreliable after 2–3 documented checks, stop and inspect reset synchronization, clocks, COM/power, without arbitrary firmware rewrites. No Flash/SD writes.

### Next exact commands (after reviewing this recorded caveat)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
$Fs = (Resolve-Path '.\01-PicoRV32\lab06\_build\fit_20261026_174759_839_3ed614\lab062_pico_nano9k.fs').Path
$SHA = '31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0'
if ((Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash -cne $SHA) {
    throw 'LAB062_BITSTREAM_SHA256_MISMATCH: DO NOT PROGRAM'
}
.\01-PicoRV32\lab04\tools\program_lab04_sram.ps1 -Bitstream $Fs
# After reviewing the dry run: SRAM ONLY
.\01-PicoRV32\lab04\tools\program_lab04_sram.ps1 -Bitstream $Fs -Program
```

Expected serial `PICORV32 READY` at `115200 8N1` once per reset and **three steady alternating LEDs** after UART. The LAB-04 programmer's old message about HDMI is irrelevant to this LAB-06 design.

Canonical acceptance: [LAB062_FIT_PREBOARD_2026-10-26.md](acceptance/LAB062_FIT_PREBOARD_2026-10-26.md).

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
