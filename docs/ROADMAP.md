# Research roadmap / этапы

> **Актуализация 23.10.2026:** таблица ниже отражает исходный план на 19 октября. Испытания PicoRV32 P1/LAB-02, CPU/HDMI PiKoSoL LAB-04.3.2 и браузерной среды LAB-04.4 завершены с аппаратным подтверждением. [Протокол LAB-04.4](lab04/LAB044_ACCEPTANCE_2026-10-23_RU.md). NEORV32, LiteX/VexRiscv и Rocket остаются исследовательскими направлениями без подтверждённой аппаратной приёмки.

## Исторический план на 19.10.2026


| Milestone | Exit condition | Status 2026-10-19 |
|---|---|---|
| P0. Repository architecture | folders, source pins, rules | PREPARED |
| P1. PicoRV32 firmware model | deterministic ROM and behavioral smoke model | MODEL_PASS |
| P2. PicoRV32 RTL simulation | Icarus tests UART and CPU + MMIO | NOT_RUN |
| P3. PicoRV32 Nano9K synth/PnR | clean timing and utilization report | NOT_RUN |
| P4. PicoRV32 Nano9K physical run | observed UART and LED + evidence | NOT_RUN |
| N1. NEORV32 core and bus adapter | independent source and interface review | PLANNED |
| N2. NEORV32 simulation/build/physical | same MMIO ABI and workloads | PLANNED |
| L1. LiteX/VexRiscv Primer25K | SoC target + compile + peripheral CSR | PLANNED |
| R1. Rocket feasibility | synthesis resource report + alternatives | PLANNED |
| R2. Rocket implementation | only if timing/resources fit | CONDITIONAL |
| C1. Comparative study | all included configurations verified | PLANNED |

## When expanding any stage

1. Specify what is to be demonstrated and what is explicitly not claimed.
2. Pin upstream dependencies; inspect their licenses.
3. Write simulation first; distinguish module TB from full-CPU TB.
4. Produce synthesis and timing reports (record CPU/clock/compiler flags).
5. Observe actual behavior and save a reproducible log.
6. Write comparative table, limitations and independent review checklist.
