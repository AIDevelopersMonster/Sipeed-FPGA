# LAB-06 W01: final controlled RV32I comparison

**STATE 2026-10-27: W01 compiler PASS, 62/62 machine words identical, real PicoRV32 SIM PASS 39609 cycles, NEORV32 SIM PASS 38162 cycles, Gowin FIT/STA preboard screen PASS for both (10/10 pin/VCCIO). Board W01 NOT RUN; Pico async-reset recovery/removal not qualified.**

This isolated workload will compare the two CPUs once each on Tang Nano 9K without changing any accepted LAB-06.1 or LAB-06.2 source or bitstream.

## Design

- Shared, byte-identical RISC-V RV32I assembly in `common/w01_workload.S`.
- 32 words of stack memory, 256 ALU/branch/load/store rounds; stack return; no dynamic allocation.
- Shared program address 0, RAM at `0x80000000` (2 KiB), 27 MHz, ROM 16 KiB.
- Deterministic digest: `B26F8CA7` from independent `common/reference_w01.py`.
- Target output: `W01:B26F8CA7:XXXXXXXX\r\n`, where `XXXXXXXX` is elapsed cycles as eight uppercase hex digits.
- PicoRV32 must enable `ENABLE_COUNTERS=1` and `ENABLE_COUNTERS64=0`; NEORV32 must enable `RISCV_ISA_Zicntr=true`. **The already accepted build of each CPU disables counters. Therefore the W01 program must not be loaded into existing approved images.**
- Native UART MMIO differs. The measured interval is only the shared function call and two `cycle` CSR instructions. UART and LEDs run before/after measurement.
- Compare cycles for the same workload and native ROM/RAM latency; do NOT claim this measures pure ALU latency. Original area comparison, with counters OFF, remains frozen separately.

## First gate — source-level oracle

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- docs/cpu-comparison/w01
python .\docs\cpu-comparison\w01\common\reference_w01.py
```

Expected `W01_REFERENCE_DIGEST=B26F8CA7` and `W01_REFERENCE_PASS`. **That check is not a CPU simulation.**

The next stage is an isolated compiler/run pipeline that must establish the exact RV32I object byte identity and two real CPU simulations before Gowin. No W01 results are claimed until the operator runs them and supplies raw receipts. W02/W03 cancelled.

For a full comparison, audit the existing Pico `BSRAM=54%` vs NEORV32 `20%` resource summaries using mapped primitive reports, not just percentages.


## Compile gate (not yet run)

The cross-compiler invokes `-march=rv32i_zicsr` to make the cycle CSR legal;
the shared workload itself only uses RV32I.

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- docs/cpu-comparison/w01
.\02-NEORV32\tools\activate_ucrt64.ps1
.\docs\cpu-comparison\w01\tools\build_w01_firmware.ps1
```

Expected W01_REFERENCE_PASS and W01_COMMON_MACHINE_CODE_PASS.
This **builds firmware only**; no CPU simulation, Gowin fitting or programming
occurs. The two previously accepted CPU images remain unchanged.

## W01 validation checkpoint, 2026-10-27

Operator ran common compile twice, with independent digest `B26F8CA7`, both ELF images generated, byte-identical 62 instruction words PASS. Then operator ran `run_w01_sim.ps1`; it issued `W01_BOTH_CPU_SIM_PASS` with job `docs/cpu-comparison/w01/_build/sim_20261027_043846_199`. From GHDL log: `W01_NEO_SIM_PASS digest=B26F8CA7 cycles=38162 bytes=23`. The Pico simulation log and cycle count are not in the submitted excerpt; the script's `BOTH_CPU_SIM_PASS` marker requires both simulator PASS logs. The result is **simulation**, not hardware speed.

Pico count can be read without any rebuild:

```powershell
Get-Content '.\docs\cpu-comparison\w01\_build\sim_20261027_043846_199\pico\sim.log' -Tail 15
```

A read-only Gowin PnR auditor is staged in `tools/audit_w01_pnr.py`, but **the W01 Gowin FIT runner is not yet accepted** and neither FPGA has been reconfigured for W01. Do not program images from the old counter-disabled LAB06.1/LAB06.2 builds with W01 firmware. Preserve previous physical board BASIC PASS results.

## W01 FIT checkpoint and final SRAM-only smoke — 2026-10-27

**W01 PnR accepted from operator transcript, not board tested yet.** Both pinned real CPUs have completed simulation. PicoRV32 simulation `39609` cycles, NEORV32 simulation `38162` cycles, both exact digest `B26F8CA7`; 62/62 identical RV32I machine instruction words.

| Counter-enabled W01 native SoC | PicoRV32 | NEORV32 |
| --- | ---: | ---: |
| Logic | 1654/8640 (20%) | 3696/8640 (43%) |
| Registers | 617/6693 (10%) | 2058/6693 (31%) |
| BSRAM | 54% | 20% |
| Setup min | +19.191 ns | +15.157 ns |
| Hold min | +0.434 ns | +0.439 ns |
| Pin mapping and BankVccio | 10/10 PASS | 10/10 PASS |
| Recovery / Removal | No analyzed paths; async reset release **NOT qualified** | Both evaluated positive |

**Exact W01 PnR job:** `_build/fit_20261027_051220_362_32058f` (ignored locally).
Pico `w01_pico_nano9k.fs` SHA256 `213D90E9A6EA8BF3A6328FEB23344F35BDD31755CF709279E7977B06F18BE3FA`.
NEORV32 `w01_neo_nano9k.fs` SHA256 `D6C489C08158EFA92EB89A244A3D9637670737F86A8CDB871EFDB1328D10E438`.
These contain **enabled cycle CSR**; do not confuse them with earlier accepted counter-disabled LAB06 bring-up images or KBlocks.

**FINAL operator commands, PowerShell 7 (one run per processor, no recompile):**

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- docs/cpu-comparison/w01/tools/board_w01.ps1 docs/cpu-comparison/w01/tools/capture_w01_uart.py
.\docs\cpu-comparison\w01\tools\board_w01.ps1 -Cpu pico
.\docs\cpu-comparison\w01\tools\board_w01.ps1 -Cpu neo
# Close existing Python miniterm and Web Serial before each board capture.
.\docs\cpu-comparison\w01\tools\board_w01.ps1 -Cpu pico -Program -Port COM10
# After W01_UART_OPEN, press physical S1 once and check three LEDs.
.\docs\cpu-comparison\w01\tools\board_w01.ps1 -Cpu neo -Program -Port COM10
# Again press S1 after COM opens; check three LEDs.
```

Each invocation uses explicit `-Cpu`, SHA lock, FIT receipt, PIN/STA and SIM receipt; it invokes existing operation_index=2 Gowin programmer for **volatile SRAM ONLY**. Python capture expects exactly `W01:B26F8CA7:XXXXXXXX\r\n` (23 bytes), saves cycle count and raw evidence. Result status remains `UART_PASS_LED_PENDING` until operator confirms LED count. **No Flash or SD.** The NEORV32 candidate has positive analyzed reset recovery/removal, Pico does not; this remains a limitation of the lab smoke. If physical runs fail 2–3 times, stop; do not rewrite previously working RTL.
