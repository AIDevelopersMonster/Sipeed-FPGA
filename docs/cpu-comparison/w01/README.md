# LAB-06 W01: final controlled RV32I comparison

**STATE 2026-10-27: W01 compile PASS twice, 62/62 machine instruction words identical, real PicoRV32 and NEORV32 CPU RTL SIM PASS; NEORV32 SIM cycles=38162; PicoRV32 cycle count in operator local log but not yet posted. W01 Gowin PnR NOT RUN; W01 board NOT RUN.**

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
