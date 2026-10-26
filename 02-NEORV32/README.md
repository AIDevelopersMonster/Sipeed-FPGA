# 02 — NEORV32 / LAB-06: comparative RISC-V and standard blocks

**Status: PROGRAMME PLAN ONLY — no NEORV32 local synthesis, simulation or BOARD PASS as of 2026-10-26.**

**Target:** Sipeed Tang Nano 9K, GW1NR-9C (27 MHz). Upstream CPU/SoC: [`stnolting/neorv32`](https://github.com/stnolting/neorv32), pin from [`sources.lock.json`](../sources.lock.json). External board reference: [`jimmyw/tang_nano_9k_neorv32`](https://github.com/jimmyw/tang_nano_9k_neorv32). Source license **must be verified before vendor import**.

**Purpose / Назначение:** Create a second board-accepted RISC-V CPU; **mandatory** compare it to PicoRV32 by measured CPU-only and minimal-SoC configurations, plus comparative implementations of CPU internal building blocks and reusable peripherals.

## Mandatory LAB-06 research package / Обязательный сравнительный пакет

- **[CPU and architecture comparison](../docs/cpu-comparison/README.md)** — controlled RV32I baseline, CPU-only vs native-SoC vs shared-IP comparison, acceptance and stop criteria.
- **[Internal CPU and peripheral blocks](../docs/cpu-comparison/TYPICAL_BLOCKS.md)** — ALU32, register file, decoder, load/store bus, UART8N1, GPIO6, timer32, SPI and later SD CMD17.
- **[Measurement protocol](../docs/cpu-comparison/BENCHMARK_PROTOCOL.md)** — same Tang Nano 9K, clocks, memory, workload, compiler, resource/STA evidence, step-by-step reproducibility.
- **[Blank measurement tables](../docs/cpu-comparison/RESULTS_TEMPLATE.md)** — no invented processor rankings or inferred pass statuses.
- **[Common experimental MMIO](../common/mmio_v0_1.md)** — comparison ABI; does **not** claim identity with all existing PiKoSoL MMIO offsets.

## Planned milestones / Вехи

| ID | Implementation scope | Acceptance criterion |
| --- | --- | --- |
| **LAB-06.1** | Minimal pinned NEORV32 RV32I, on-chip ROM/RAM, 115200 UART, six LEDs; no HDMI/SD/user Flash | SIM + Gowin FIT/STA + 2–3 board checks, real `NEORV32 READY` and GPIO behavior |
| **LAB-06.2** | Matching minimal PicoRV32 CPU and SoC, not full PiKoSoL+HDMI | Same workloads, tool version, clock, ROM/RAM size where possible and separate CPU/SoC resources |
| **LAB-06.3** | Study and compare ALU32 / regfile32×32 / RV32I decoder, plus standardized UART/GPIO/TIMER | Common deterministic tests and exact implementation/adapter overhead measurement |
| **LAB-06.4** | SPI mode 0 and **read-only** CMD17 SD experiment | First common IP/bridge simulation, then measured FIT and read-only physical evidence |
| **Later** | Native memory boot alternatives, debug, traps/interrupts, Zephyr, HDMI | Separate independently justified work packages |

### Engineering restrictions / Ограничения

- **Bring-up budget: 1–2 days.** If 2–3 documented board tests fail, stop rewriting RTL and diagnose physical clock/reset, FT2232 COM drivers, JTAG, pinout, memory and STA.
- **Do not use Flash** in the initial NEORV32 experiments. External board tutorials that use Gowin embedded **user Flash** are reference material only. Program the FPGA **volatile SRAM** with the established local CLI toolchain when a safe exact-build candidate exists.
- Separate architecture features from area/throughput claims: NEORV32 includes optional UART/GPIO/timer; the bare PicoRV32 CPU does not. Comparing a complete NEORV32 SoC to a bare PicoRV32 core would be invalid.
- Do not redistribute upstream vendor tools, generated proprietary IP, or external board source without reviewing per-component licenses.
- Keep PiKoSoL v0.2.0 and SD-06 qualified evidence unchanged. SD-07 CPU+HDMI+CMD17/CMD24 remains a **FIT-ONLY candidate**, not a precondition for the second CPU.
- A board-level test must be bound to exact source commit, compiler, PnR/STA reports and bitstream SHA.

## Directory contract / Будущая структура

Create directories **only when implementations exist**: `rtl/`, `firmware/`, `tests/`, `constraints/`, `reports/`. Put reusable blocks in a common peripheral library **only after** the actual matching hardware contract exists, rather than duplicating untested modules.

**English summary:** NEORV32 is the next CPU bring-up candidate on Tang Nano 9K. LAB-06 also measures processor architecture and implements/comparatively tests internal ALU/register-file/decoder and standardized UART/GPIO/timer/SPI peripherals. CPU-only, native-SoC and identical shared-IP configurations must be kept distinct. No benchmark or board PASS is yet claimed.
