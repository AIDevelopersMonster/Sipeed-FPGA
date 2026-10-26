# LAB-06 — Comparative RISC-V and reusable CPU blocks / Сравнение процессоров и типовых блоков

**Programme status (2026-10-26): LAB-06.1 NEORV32 minimal native-SoC board bring-up PASS (SRAM, UART `NEORV32 READY`, three LEDs observed). Matched PicoRV32-vs-NEORV32 CPU/core and W01/W02/W03 benchmarks NOT MEASURED.** Existing PicoRV32/PiKoSoL and RetroStation results are not matched minimal SoC/core baselines; keep comparisons separate.

**Goal / Цель:** bring up a **second independent RISC-V processor**, then create a fair and reproducible comparative analysis of **processor cores, complete minimal SoCs, internal CPU blocks and standard peripherals**. The CPU comparison is useful only if the hardware configuration, workloads and measurement methods are documented.

Start with **PicoRV32 vs NEORV32 on one Sipeed Tang Nano 9K / GW1NR-9C**, 27 MHz board clock, SRAM-only FPGA programming. Later add LiteX/VexRiscv and Rocket only as new board-specific rows, never as unqualified 9K equivalents.

## 2026-10-26 checkpoint: first NEORV32 native-SoC physical bring-up

- NEORV32 upstream `b2620454ebb2407e81a6a1965ef52e2a860b0432`, architecture `CPU_RF_ARCH_SEL=2`, 27 MHz, ROM16KiB, RAM2KiB, UART0/GPIO6 on Tang Nano 9K.
- SIM PASS, PnR/STA preliminary PASS, BankVccio 10/10 PASS, SRAM-only programming 100% PASS, hardware UART `NEORV32 READY` PASS, physical LED-on-count=3 operator-confirmed with photograph.
- Exact approved image SHA256 `3E1DC3EB6DC464E3992C733078A564680D5F279E4D89BAA8A47CB9002246FC5F`.
- Resource report (whole native mini-SoC, **not bare CPU**): logic 3228/8640 (38%), LUT 3052, ALU 122, FF 1921 logic + 2 I/O, BSRAM 20%.
- Exact six-bit LED pattern by independently identified physical LED pins, full external timing signoff, and comparative instruction-cycle throughput **NOT** established.
- Next study: `LAB-06.2` matched PicoRV32 minimal SoC with explicit memory footprint correction (current NEORV32 DMEM is 2KiB; planned protocol default had 1KiB target), then deterministic `W01/W02/W03` experiments. Do not claim winner based on incomparable PiKoSoL HDMI or game firmware.

Full receipt: [NEORV32 physical board acceptance](../../02-NEORV32/acceptance/LAB061_BOARD_2026-10-26.md).

## 1. What exactly are we comparing? / Что сравниваем?

| Comparison domain | PicoRV32 path | NEORV32 path | Controlled result |
| --- | --- | --- | --- |
| **A — CPU core** | Bare PicoRV32 core in a minimal wrapper | NEORV32 CPU-only or the smallest accessible wrapper with identical exposed memory/IO semantics | LUT/FF/BSRAM, max frequency, timing, cycles per workload |
| **B — Minimal SoC (native)** | PicoRV32 + our ROM/RAM, UART, GPIO, timer | NEORV32 processor with its documented built-in ROM/RAM, UART, GPIO and timer | End-to-end usability, total SoC area and boot complexity |
| **C — Shared peripheral IP** | Core + CPU-specific bridge + common block | Core + NEORV32 XBUS-compatible bridge + **same common block** | Adapter overhead, peripheral efficiency and portability |
| **D — Internal building blocks** | Study PicoRV32 ALU/decoder/register-file/control implementation | Study NEORV32 equivalents in VHDL | Architecture and HDL implementation trade-offs; independent educational reference RTL if useful |

**Do not claim CPU A is faster/larger based on B, C or an existing PicoRV32+HDMI full PiKoSoL result.** NEORV32 is a configurable processor **and** an SoC with optional internal peripherals; PicoRV32 is a bare core and its PiKoSoL peripheral set is project-specific.

## 2. Architectural comparison / Архитектурная матрица

| Dimension | PicoRV32 | NEORV32 | Comparison rule |
| --- | --- | --- | --- |
| Hardware language | Verilog | Native VHDL; upstream also documents a GHDL-generated Verilog option | Pin exact revision and transformation method |
| Intended role | Small standalone RISC-V core with native memory interface, optional AXI4-Lite wrapper | Configurable RISC-V CPU + microcontroller-style SoC | Separate core-only and SoC results |
| Baseline ISA | Select **RV32I** (no optional M/C in the controlled baseline) | Select matching **RV32I** with only mandatory CPU dependencies | Record all parameters; extra ISA extensions are a **separate** row |
| Datapath/control | Compact iterative/control-oriented implementation, configurable register-file organization | Different implementation and configurable system-level CPU options | Report register-file ports, memory handshake and CPI; do not infer from source size |
| Interrupt/trap behavior | Optional PicoRV32 custom IRQ instructions (not standard RISC-V privileged interrupt architecture) | Standard machine-mode trap/interrupt mechanisms as configured | Never compare IRQ latency before documenting different semantics |
| Memory access | Native `mem_valid/mem_ready` protocol and memory adapter | Native NEORV32 system bus / optional XBUS with Wishbone-compatible attachment | Measure bridge cost and actual wait states |
| Peripherals | External to bare CPU (PiKoSoL has project-specific UART/LED/HDMI) | Optional native UART/GPIO/SPI/timer and others | Compare native SoCs separately from identical external IP |
| Program load | PiKoSoL uses an on-chip ROM/RAM and SRAM FPGA bitstream | First LAB-06 should use on-chip boot, without user-flash/Zephyr | Same board programming risk level: SRAM only |
| Bench data | Existing PicoRV32 FULL SoC board evidence, not a matched minimal benchmark | **LAB-06.1 native SoC smoke PASS** (UART boot, three LEDs) | **W01/W02/W03 NOT RUN**; new matched measurements required for both |

**Sources:** [PicoRV32 upstream](https://github.com/YosysHQ/picorv32), [NEORV32 upstream](https://github.com/stnolting/neorv32), [NEORV32 user guide](https://stnolting.github.io/neorv32/ug/), [NEORV32 9K external reference](https://github.com/jimmyw/tang_nano_9k_neorv32), [this project's pinned sources](../../sources.lock.json).

**Reference warning:** the external Tang Nano 9K NEORV32 port uses FPGA user Flash for its program. That design is a **reference, not a programming procedure for LAB-06**. Initial acceptance is volatile FPGA SRAM and a tiny on-chip program, **no user-Flash writes**.

## 3. Mandatory comparison axes / Обязательные измерения

- **Resources:** GW1NR-9C LUT / ALU / FF / BSRAM / DSP / PLL / Logic / CLS / IO. Record native per-core and complete-SoC utilization, not totals copied from unrelated builds.
- **Timing:** actual clock(s), post-route setup/hold/recovery/removal slack, violations, unconstrained/CDC checks, full relevant STA report, and Fmax with its qualification.
- **Instruction execution:** common RV32I test vectors, deterministic arithmetic/branch/load-store checksum and **measured cycles** (use a shared fabric counter if CPU cycle CSR semantics differ).
- **Firmware:** binary length, ISA compiler flags, actual ROM/RAM sizes and maps; differences in linker/runtime must be recorded.
- **Integration:** UART fidelity at 115200 8N1, six LEDs, timer accuracy; after first successful basic comparison add SPI and optional SD read-only.
- **Software and engineering effort:** tool versions, source SHA, build duration, integration/debug notes, test outcomes, and reasons for excluded features. Never equate LoC with silicon area.

## 4. Staged programme / Этапы

**LAB-06.1 — Bring-up (time-box: 1–2 days).** Pin NEORV32 source from `sources.lock.json` and verify license. Build **minimal** RV32I, ROM/RAM + UART + 6 LEDs, 27 MHz, no HDMI, SD, Zephyr, DMA, caches, user-Flash or ISA extensions outside the declared baseline. Produce `NEORV32 READY` on UART and LED test marker; require sim → Gowin FIT/STA → at most 2–3 physical tests. A 9K FIT failure is an engineering result, not permission for unlimited RTL rework.

**LAB-06.2 — Matched baseline.** Make a **new** PicoRV32 minimal reference with exactly declared ROM/RAM and UART/LED. Run the same tests and measurement method, record separate CPU-only and full-SoC numbers. Do not compare against old PiKoSoL+HDMI resource figures.

**LAB-06.3 — Educational blocks.** Implement and independently test common `ALU32`, `regfile32x32` (1 vs 2 read ports clearly annotated), `RV32I decoder`, `UART8N1`, `GPIO6` and `timer32`. Compare source-level structures and Gowin cells with the corresponding blocks inside each processor/SoC **without copying code into a differently licensed derivative**. Use identical test vectors; allow native blocks to have extra documented features.

**LAB-06.4 — Shared peripherals.** Add optional SPI mode 0 and then SD **CMD17 read-only** using proven modules where sensible; first benchmark common hardware IP + per-CPU adapter. SD write/FILES is **not** part of LAB-06 bring-up. Keep the previous SD-06 sector-write evidence separately frozen.

**Later:** run an equivalent protocol on an actually available Tang Primer 20K/25K target for LiteX/VexRiscv; compare separate FPGA devices only with a prominent non-equivalence note. Rocket remains conditional.

See [standard blocks and adapters](TYPICAL_BLOCKS.md), [measurement/acceptance protocol](BENCHMARK_PROTOCOL.md) and [blank results template](RESULTS_TEMPLATE.md).

## 5. Stop rule / Критерий остановки

Bring-up is limited to **1–2 days and 2–3 documented board tests**. For persistent failures stop software changes and examine FPGA reset/clock, serial channel, pins, USB/JTAG cable, power and timing. No pointless repairs of inexpensive boards. Preserve all failed measurements and tool output as engineering evidence.

## English quick summary

LAB-06 adds **two orthogonal comparisons**: CPU core architecture vs complete SoC integration, plus a separate comparison of **identically specified ALU, register-file, decoder, UART, GPIO, timer, memory and SPI blocks**. LAB-06.1 NEORV32 basic physical boot/UART/three-LED observation PASS; **comparative performance measurements remain NOT RUN** until exact-source, exact-bitstream fixed-board benchmarks exist for both PicoRV32 and NEORV32. SRAM-only programming; no SD write or on-chip user-Flash workflow in the first stage.
