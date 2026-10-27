# LAB-06 W01: final controlled RV32I comparison

**STATE: SOURCE PREPARED; W01 CPU simulation NOT RUN, W01 PnR NOT RUN, W01 board NOT RUN.**

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
