# LAB-07 / Tang Nano 9K — PSRAM bring-up (memory, not another game)

**Status 2026-10-27: Gowin PnR CANDIDATE PRODUCED by operator (SHA-256 D3E38926012EC2C7E7762D69553446E1BBDC9B05038A68A24165E1C3F74EE21B); 81MHz clock/DDR PSRAM/pin/STA audit NOT YET COMPLETE. No LAB-07 simulation or physical hardware run.** LAB-06 CPU comparison is closed; KonSol RetroStation is developed separately in another project and is **outside LAB-07**.

## Engineering goal

Demonstrate **real volatile PSRAM read/write** on **Sipeed Tang Nano 9K / GW1NR-LV9QN88PC6/I5**, without CPU, SD, HDMI or Flash. This is preparatory infrastructure for a future PicoRV32 **large RAM, program loader, or FAT32-backed application**, not a promise that code can yet be executed from PSRAM.

Official Tang Nano 9K specifications list **64 Mbit = 8 MiB** of PSRAM. However, the pinned independent controller below explicitly accesses only **one of two dies (4 MiB)**. The first reference test writes/reads **only the first 1 MiB**, using a deterministic address-derived byte pattern. A PASS cannot be extrapolated to 4 MiB or 8 MiB coverage without additional tests.

Board vendor: [Sipeed Tang Nano 9K](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K.html). Controller reference: [zf3/psram-tang-nano-9k](https://github.com/zf3/psram-tang-nano-9k/tree/394ae14a68f112729f79f78cbfc62a95d874d632), pinned commit `394ae14a68f112729f79f78cbfc62a95d874d632`, Apache-2.0 for reference source. **Do not copy the vendor-generated Gowin PLL file into our public repo**; only use local ignored staging.

## Why this scope is necessary

Previously accepted RISC-V experiments use only **16 KiB ROM / 2 KiB RAM** inside the SoC. LAB-07 must first test PSRAM *independently* of the processor. Adding a PicoRV32 bus bridge or an SD-based loader before proving the memory would conflate fault sources and waste board time.

The open-source reference uses Gowin DDR primitives `ODDR` / `IDDR` and a clock from an `rPLL`; it avoids the closed Gowin PSRAM Controller IP core. The reference controller runs at **81 MHz** with a **90-degree phase-shifted clock**, with initialization and DDR command/data timings. These are **not** the 27MHz clock-only conditions already qualified for LAB-06. The published test top sends status over UART (115200) and uses a 1 MiB read/write sweep. It reports `All done successfully.` only after the pattern check completes. Error categories include initialization, read/write timeout and wrong data.

## Important board-specific patch

The upstream reference constraint map uses `sys_resetn` on **pin 4** and a button on pin 3. **We do not reuse that mapping:** the physically verified Tang Nano 9K baseline already uses S1 reset **pin 3**, I/O standard `LVCMOS18` and pull-up; clock **pin 52 LVCMOS33 BankVccio=3.3V**, UART TX **pin 17 LVCMOS33**, LEDs pins 10, 11, 13, 14, 15, 16 (`LVCMOS18`). A specific LAB-07 constraint file is supplied and the unused button port is removed from the staged upstream test top. Do **not** silently program the original reference `tang9k.cst`.

Additionally, the original test top constructs a **22-bit expression for six LEDs**, truncating the intended error flag. The local ignored staged copy fixes this to `assign led = ~{error, 1'b0, state};`. Original pinned upstream files are NEVER edited. PSRAM special ports `O_psram_*` and `IO_psram_*` are embedded-memory interface signals; do **not** give them arbitrary user header pin locations.

## First step (PowerShell 7, non-hardware)

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- boards/tang-nano-9k/experiments/psram07

# Fetch/read-only audit of pinned Apache-licensed reference.
.\boards\tang-nano-9k\experiments\psram07\tools\prepare_psram07.ps1
```

Expected **not yet verified on the operator PC**:
```text
LAB07_REFERENCE_PIN_PASS: 394ae14a68f112729f79f78cbfc62a95d874d632
LAB07_MEMORY_SCOPE: 64Mbit total PSRAM; demo addresses only FIRST DIE, FIRST 1MiB
LAB07_BOARD_PIN_PREFLIGHT_PASS: clock52, reset3, UART17; voltage constraints pinned.
LAB07_PREFLIGHT_PASS_NO_FPGA_ACTION
```

## Second step (isolated synthesis only, not programming)

After preflight, optionally invoke:

```powershell
.\boards\tang-nano-9k\experiments\psram07\tools\prepare_psram07.ps1 -Build
```

This stages the pinned controller, unchanged PLL reference and UART/test source plus two explicitly identified board-local adjustments, hashes all inputs and runs Gowin CLI to produce a possible `psram07_nano9k.fs`. **Even if FIT completes, there is NO automatic authorization to program.** Review the post-route report's actual **81MHz derived clock timing, DDR PSRAM interface and special port mapping, Setup/Hold/Recovery/Removal and unconstrained paths** before a single bounded SRAM smoke run. This script has no `programmer_cli` call.

## Acceptance and stop criteria

1. **READ-ONLY PREPARATION:** upstream exact commit and license PASS, board pin differences documented and source staging SHA manifest.
2. **GOWIN SCREEN:** exact target GW1NR-9C, PSRAM interface actually mapped, 81 MHz PLL clock and PSRAM path timing verified, no relevant violations. Negative or inconclusive timing evidence is a **stop**, not PASS.
3. **PHYSICAL SMOKE (later):** one SHA-locked `operation_index 2` SRAM load, external UART `All done successfully.` without a FAIL marker, physical LED sanity. Success means only **first 1 MiB one-die** data test — no inference of full 8 MiB, no CPU access yet.

**Time-box:** 1–2 days maximum, 2–3 documented board attempts at most. Recurrent failures move to power/USB/FTDI/reset/clock/PSRAM hardware diagnostics; no iterative rewrites of accepted PiKoSoL/SD/RetroStation. If the controller will not fit or cannot meet DDR timing, stop and record it, rather than moving on to CPU integration.

**Follow-up if LAB-07 passes:** memory-mapped PicoRV32 adapter, CPU-side memory test; only then a read-only FAT32 program load into validated RAM. Each is a *separate stage*, not implicit success of this bring-up.

## USB/JTAG recovery note (27 October 2026)

On one Windows CHUWI setup, the board temporarily enumerated as `VID_FFFF&PID_FFFF` / COM28 instead of the expected `VID_0403&PID_6010` WebUSB profile after moving between PCs. The operator **recovered normal USB access by disconnecting BOTH USB and HDMI and removing residual power**, not by changing drivers or reflashing BL702. If the symptom recurs, first power down fully and reconnect USB before HDMI. This is an observed recovery, **not proof of the specific back-powering mechanism**. LAB-07 synthesis stage needs no USB/JTAG connection.

The isolated Gowin candidate receipt uses `PlannedFirstDieSweepBytes` and `PhysicallyVerifiedExternalMemoryBytes=0` until a real board test is recorded; do not interpret a generated `.fs` as memory acceptance.


## Operator's PnR result, 27 October 2026 (not a PSRAM PASS)

First produced candidate:
- build folder: `_build/fit_20261027_101531_279`;
- bitstream SHA-256: `D3E38926012EC2C7E7762D69553446E1BBDC9B05038A68A24165E1C3F74EE21B`;
- `LAB07_PNR_CANDIDATE_SHA` and `LAB07_HARDWARE_BLOCKED` both reported by local preparation script.

**Exact read-only report extractor (PowerShell 7; no rebuild):**

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- boards/tang-nano-9k/experiments/psram07/tools/inspect_psram07_fit.ps1
.\boards\tang-nano-9k\experiments\psram07\tools\inspect_psram07_fit.ps1
```

Paste the summary (SHA, Gowin port table, Clock Summary, STA violation markers, Setup/Hold/Recovery/Removal, PSRAM/PLL log lines) for independent audit. This report **does not** automatically claim FPGA DDR closure or allow SRAM programming. If 81MHz derived clock timing or PSRAM special-port mapping cannot be established, **STOP** until those can be verified; do not flash the FPGA or BL702.


## LAB-07.1 — timing repair candidate (not yet tested)

Original 81MHz PnR bitstream SHA `D3E38926012EC2C7E7762D69553446E1BBDC9B05038A68A24165E1C3F74EE21B` was **not allowed for SRAM**: 63 violated Setup endpoints; worst -1.921ns; actual Fmax 70.093MHz. Worst Setup paths were in `print_buffer_pointer`/`print_seq`, not necessarily in PSRAM controller. Hold violated endpoints: 0.

An optional `-LeanUart` build replaces only the reference's 1024-bit dynamic-indexed UART printer in a new **ignored staged copy** with a small 14-byte terminal result reporter. Full PSRAM write/read algorithm, 81MHz clock, LVCMOS pin assignments, and 1MiB test footprint remain unchanged. Fixes a non-applied upstream `defparam` by explicitly specifying its existing 81MHz default, removes unused parity wire. Original PSRAM controller and its first-candidate FS are preserved.

UART reports `PSRAM07:PASS\r\n` after entering FSM state 4 (readback complete) or `PSRAM07:FAIL\r\n` on FSM states 5–8. No initial progress prints or latency counters. A required standalone Icarus testbench checks both 14-byte messages *before* Gowin FIT. The testbench **does not** simulate the PSRAM electrical interface.

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
git fetch origin
git restore --source origin/main --worktree -- boards/tang-nano-9k/experiments/psram07
.\boards\tang-nano-9k\experiments\psram07\tools\prepare_psram07.ps1 -Build -LeanUart
```

Expected earliest gate: `LAB07_UART_TB_PASS`. This produces a different PnR candidate and SHA if Gowin FIT completes. **Do not program FPGA yet**: derived 81MHz clock, Setup=0, PSRAM DDR special ports and unresolved original warnings require an independent check. Further unresolved timing issues are a stop under LAB-07 time-box.

## LAB-07.1 UART testbench correction (2026-10-27)

The first `-Build -LeanUart` invocation stopped *before Gowin FIT*: the testbench checked 14 UART bytes, matched the first 12 characters, then expected `0x72` (ASCII `r`) while RTL emitted the correct `0x0D` CR at index 12. The root cause was testbench use of Verilog `"\\r"` in an expected string. Only `tests/tb_lab07_uart_result.v` was corrected to concatenate exact numeric `8'h0d, 8'h0a` for both PASS and FAIL frames; **RTL, source PSRAM controller, build script, existing bitstreams and 81MHz timing constraints are unchanged**. A successful UART test is still only a pre-Gowin gate, not a PSRAM result. Re-run the same `-Build -LeanUart` command after pulling the corrected test file.

## LAB-07.1 — UART testbench reset-sequence correction, 27 October 2026

Second local Icarus failure: `UART byte 0 got 35 expected 50`, after correcting CR/LF. The testbench did not clear `test_state=4` (prior PASS) when resetting the UART. On reset deassertion, the diagnostic sender detected PASS again before the testbench requested FAIL (`test_state=8`), and the receive task sampled the middle of the unsolicited frame. Corrected solely in the TB: set `test_state=0` while asserting reset, check UART remains idle after deassertion, then set `test_state=8`. No PSRAM/PLL/DDR/RTL firmware changes. GitHub Actions now runs the exact Icarus UART test on pushes and pull requests that change this TB or UART RTL; a green workflow is evidence of only standalone UART simulation. The physical memory test remains blocked pending PnR STA and DDR-interface review.

## LAB-07.1 second Gowin PnR result (2026-10-27)

After `LAB07_UART_TB_PASS`, the operator successfully ran lean-UART Gowin FIT. New job: `fit_20261027_120909_174`. Exact bitstream SHA-256: `98FAA94E4C53A52C59F2DD7AB206A78E953134E7C071BBCD01C996A7508C21F5`. Its STA and PSRAM internal-port assignment **have not yet been audited**. The original PnR candidate and SHA remain preserved. The read-only `inspect_psram07_fit.ps1` now accepts `-FitJob` and `-ExpectedSha`; original defaults retained. Zero Setup/Hold reported violations do not by themselves prove DDR timing closure or authorize hardware.
