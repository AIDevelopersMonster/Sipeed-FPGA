# LAB-03.1 — passive real-bus event capture for PicoRV32

**Project:** Sipeed FPGA · Tang Nano 9K · PicoRV32 RV32I · 20 October 2026  
**Milestone:** LAB-03.1 v0.1.0 (RTL tests PASS on 20 October 2026; Gowin/physical FPGA not tested)  
**Educational experiment:** A. A. Malachevsky, ORCID 0009-0008-6009-3196  
**Repository:** https://github.com/AIDevelopersMonster/Sipeed-FPGA

## Scope and nonclaims

LAB-02 let an HTML application command a physical FPGA over UART, with an `L=n` reply after MMIO readback. The previous 19-step animation remained a **conceptual four-instruction teaching model**. LAB-03.1 instead captures actual **accepted PicoRV32 memory transactions**, without modifying the proven LAB-02 design. It is currently a **passive RTL-testbench attachment**: neither the synthesized board design nor the UART protocol exposes trace data yet. Those steps belong to LAB-03.2.

The independent observer samples the existing SoC's `mem_valid`, `mem_ready`, `mem_instr`, address, read and write data, strobes, and the UART receiver's `rx_valid/rx_byte` signals. It never asserts `mem_ready` or backpressures the CPU.

| Event | Required condition | Stored fields | Crucial nonclaim |
|---|---|---|---|
| `FETCH` (`01`) | accepted `mem_valid && mem_ready && mem_instr`, no write strobe | real ROM read address and 32-bit instruction word | not a retirement/commit event |
| `LED_WRITE` (`10`) | accepted data write to `0x20000000` | MMIO address and 32-bit write data | not an optical reading |
| UART trigger | valid ASCII command `0`–`6` | stored separately in `command` | not proof the CPU consumed the byte |

A **128 × 82-bit** bounded capture memory stores `(16-bit relative cycle, 2-bit type, 32-bit address, 32-bit value)` per event. Snapshots finish with `done=1` **only after an accepted LED write**. Filling early sets `truncated`, a second command sets `overlap` and aborts, and 16-bit timestamp rollover sets `timestamp_wrapped`. After completion, the snapshot can be read synchronously one word per request; no ring-buffer overwrite occurs. Resource utilization, Fmax and implementation feasibility have not yet been measured with Gowin.

## Reproduce in Windows PowerShell 7

```powershell
Set-Location C:\GitHub\Sipeed-FPGA
python .\01-PicoRV32\tools\test_lab03_contract.py
& .\01-PicoRV32\tools\test_lab03_1.ps1 -UnitOnly
& .\01-PicoRV32\tools\fetch_picorv32.ps1
& .\01-PicoRV32\tools\test_lab03_1.ps1
```

`iverilog`, `vvp`, Python and the ISC-licensed pinned PicoRV32 `ef203c2b0a3fb793280f5114941416c425c5b461` are required for the complete SoC test. The full runner regenerates **only the existing LAB-02 ROM artifacts** from `boot.S`; inspect `git status -sb` afterward. It does not program SRAM/flash or open COM.

The standalone test covers capture triggering, `mem_ready` handshake, filtering, snapshot readback, early buffer full, last-slot LED store, and overlapping commands. The integration test sends real 115200-8N1 serial command `4` into the already proven LAB-02 PicoRV32 SoC, compares every captured fetch with `boot.hex`, verifies the accepted `0x20000000 ← 0x8` transaction and observes the UART `L=4` response.

**Observed laboratory output (user-provided Windows / PowerShell / Icarus Verilog test, 20 October 2026):**

```text
LAB03_1_SOURCE_PREFLIGHT_PASS: source, TBs, 1 KiB LAB-02 ROM; NOT RTL/PNR/BOARD
LAB03_1_TRACE_UNIT_RTL_PASS: triggers, accepted transfers, readback, full, exact-fit, overlap
ASSEMBLE PASS: 118 instructions, 1024 B ROM, labels=22
LAB03_1_SOC_TRACE_RTL_PASS: command=4, events=22 fetches=21 LED_STORE=0x8, verified boot.hex and L=4
LAB03_1_RTL_PASS: recorder and real PicoRV32-SoC trace. FPGA PnR/BOARD NOT TESTED.
```

## Evidence ledger (at release)

| Verification | Status |
|---|---|
| Source/ROM preflight | `SOURCE_PREFLIGHT_PASS` |
| Isolated RTL recorder simulation | **RTL_PASS** (20 October 2026) |
| Full PicoRV32 SoC + trace RTL test | **RTL_PASS**: command `4`, 22 events (21 FETCH + 1 LED_WRITE), `0x8`, verified `boot.hex`, reply `L=4` |
| Gowin synthesis/PnR/STA with a trace-connected top level | **NOT STARTED** |
| FPGA board/physical UART trace transport | **NOT STARTED** |
| Live actual trace in HTML | **NOT STARTED** |

The `-UnitOnly` runner also printed `LAB03_1_UNIT_RTL_PASS ONLY`. Nonfatal Icarus `timescale` and PicoRV32 `@*` sensitivity warnings were reported. This is user-provided Windows laboratory evidence, not independent GitHub Actions replication. An acknowledged FETCH is not proof of architectural retirement. LAB-03.1 has **not** undergone Gowin PnR/STA or FPGA board testing.

LAB-03.2 must provide synthesizable SoC integration and a versioned readout command with complete flags and snapshot length, followed by a new Gowin and physical verification. LAB-03.3 may then display real trace events **alongside** the conceptual teaching model, clearly labeling their distinct meanings.

**Upstream processor:** PicoRV32 © Claire Xenia Wolf, ISC. Original project material: MIT. Neither license is changed by the trace prototype.
