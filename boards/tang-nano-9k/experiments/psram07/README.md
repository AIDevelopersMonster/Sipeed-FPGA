# LAB-07 / Tang Nano 9K — PSRAM bring-up (memory, not another game)

**Status 2026-10-27: READ-ONLY PREPARATION AVAILABLE. No LAB-07 simulation, Gowin FIT or hardware run has yet been performed.** LAB-06 CPU comparison is closed; KonSol RetroStation is developed separately in another project and is **outside LAB-07**.

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
