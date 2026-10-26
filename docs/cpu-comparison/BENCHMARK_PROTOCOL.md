# LAB-06: Reproducible CPU and block benchmark protocol / Протокол испытаний

**Status: NOT RUN.** This document defines the experiments and does **not** contain measured CPU comparison results.

## Common baseline (C0) / Единые условия

| Parameter | Controlled requirement |
| --- | --- |
| FPGA | The same physical **Sipeed Tang Nano 9K / GW1NR-9C**, same speed grade and power/USB setup |
| Input clock | 27 MHz; count any derived clocks/PLLs and do not substitute other Fmax values for measured runtime |
| CPU ISA | **RV32I, ILP32**; no RVC, multiplication/division, caches, debug, HDMI, SPI/SD in baseline unless explicitly required and disclosed |
| Firmware | Identical task/source semantics; target-specific startup/linker permitted only if fully recorded |
| Memories | Target **16 KiB program ROM + 1 KiB data RAM**; if NEORV32 requires a larger power-of-two or reserved footprint, mark baseline as **not exactly matched**, record the actual resources, and run a second normalized configuration |
| Peripherals | UART **115200 8N1** and logical 6-bit LED GPIO; 32-bit fabric timer for comparable cycle measurement |
| Compiler | Pinned RISC-V GCC/assembler, `-march=rv32i -mabi=ilp32`; record optimization level, exact command and binary size |
| FPGA tool | Same Gowin version, actual device, speed grade, PnR strategy, STA corner/constraints and run environment; retain exact bitstream hash |
| Configuration | Volatile FPGA **SRAM only**. External Nano 9K NEORV32 tutorials that write user Flash are not accepted for LAB-06 |
| Build isolation | Separate timestamped job directories; immutable upstream revisions, SHA manifest and evidence files |

**Important:** NEORV32 CPU may require privileged-mode infrastructure or additional mandatory memory/register features. Record them in the **native** profile and do not quietly count them as equal to a bare PicoRV32 core.

## The three initial reproducible workloads

| ID | Workload | Correctness gate | Performance metric |
| --- | --- | --- | --- |
| **W01-RV32I** | Fixed list of 32-bit ALU/shift/branch/load/store instructions, including edge cases, produce deterministic digest | Matching reference digest and trace of retire/loads/stores | Fabric cycles per **fixed workload** and CPI estimate only when retired-instruction count is observable |
| **W02-UART** | 256-byte binary pattern (including 0x00, 0xFF) echoed by firmware over 115200 8N1 | Byte-exact response, no unexplained loss; UART errors recorded | Total cycles/time, bytes/s; reset and startup separately |
| **W03-GPIO/TIMER** | 1,024 writes of LED masks in prescribed order, timer reads and wraparound simulation | Expected final GPIO mask, counter progression, verified timing of toggles | Fabric cycles and FPGA resource increment |

After baseline, add `W04-SPI`: 32-byte mode-0 simulated duplex transfer with identical clock/CS properties; optional 512-byte fixed test sector (`CMD17` read-only) on verified removable media. Never include a write during CPU bring-up.

**Do not use an unstable PC terminal screenshot as the only proof of CPU performance.** Use deterministic UART frames with clear start/end markers and a fabric timer. For physical timing, serial transmission overhead may dominate; report CPU cycle results and overall I/O throughput separately.

## Required report contents

Record each build as one immutable row; see [results template](RESULTS_TEMPLATE.md).

- Processor name, pinned source commit, processor configuration/generics/parameters and ISA.
- Which comparison level: `CPU_CORE`, `NATIVE_SOC`, `COMMON_IP_SOC`, or `STANDALONE_BLOCK`.
- Board/chip/speed grade and exact 27 MHz + PLL clock tree.
- Program/data memory mapped address and real sizes, BRAM inference, first-instruction fetch behavior.
- Compiler/linker command, executable SHA, test vector SHA, input source hashes.
- Gowin version, PnR settings, post-route timing files and their hashes, actual FPGA `.fs` SHA.
- Logic/LUT/ALU/FF/BSRAM/DSP/PLL/CLS, routing errors, setup/hold/recovery/removal minimum path slacks and violated endpoint counts.
- Simulator PASS/FAIL and log, full-chip FIT PASS/FAIL, board PASS/FAIL, exact UART transcript/CRC and visual LED notes.
- Instruction/cycle count and `W01` result digest; timing boundaries for `W02` and `W03`.
- Excluded extensions/peripherals, bus adapter footprint, unresolved CDC/I/O constraints and any deviations from the common baseline.

## Measured comparison — how to read data

Create a resource table with **two separate columns per processor**: CPU-only and CPU+minimal SoC; note if one column is unavailable because a processor requires hard-wired minimal infrastructure.

Then run a **block-cost** experiment with the same base configuration:

```text
BASE = CPU + RAM + bus adapter
WITH_GPIO = BASE + identical shared GPIO6
WITH_UART = BASE + identical shared UART8N1
WITH_TIMER = BASE + identical shared TIMER32
DELTA(block) = resource(WITH_BLOCK) - resource(BASE)
```

**Caution:** differences are **measured synthesis deltas**, not intrinsic or necessarily additive module costs: logic optimizations, register sharing, device primitives and I/O pin constraints may change other netlist cells.

For each block also compare the separately configured **native** implementation. A native UART with FIFO/interrupts and a simple 8N1 UART without them are not functionally equivalent even if they echo the same bytes. Record implemented options explicitly.

Never compare measured Fmax of one **different FPGA family** directly with Tang Nano 9K as a CPU ranking. Resource numbers from a 25K board are a new target-specific dataset.

## Acceptance and stop gate

1. **Preflight / SIM:** pinned sources, legal provenance, ISA and memory compatibility, waveform/self-checking testbench, deterministic program image.
2. **Gowin / STA:** resource fit + generated clock coverage + zero relevant setup/hold violation counts, positive measured margins for setup, hold, recovery, removal, with CDC/unconstrained path audit.
3. **Physical BOARD:** max **three** documented 9K tests: UART boot identity, GPIO outputs, deterministic W01/W02 check. Hash the programmed SRAM candidate and preserve logs.

If first NEORV32 bring-up cannot pass in 1–2 days with 2–3 sensible board attempts, declare `BLOCKED`, diagnose hardware/clock/boot/COM/constraints and **stop**. No silent use of user-Flash, no rebuilding the entire platform to mask a failed pinout.

`PASS` belongs only to the exact tested bitstream and configuration. A statement such as “NEORV32 is N% faster/smaller” requires both CPU rows under the agreed method, not an external reference example.
