# Research roadmap / этапы

## Актуализация на 22 октября 2026 года

**PicoRV32 / Tang Nano 9K:** LAB-02 UART/LED испытаны на плате; LAB-03.2/03.3 дали **12 аппаратных T3-захватов** (269 FETCH, 12 LED_WRITE); LAB-03.4 завершён реальным Icarus-прогоном и независимым аудитом: нормализованные последовательности принятых шинных событий команды `0` и команды `4` совпали с шестью аппаратными захватами каждой. [Итоговый протокол LAB-03.4](lab03/LAB03_4_FINAL_AUDIT_20261022_RU.md) и [инструменты Observatory / Calc / QuizLab](lab03/README.md).

**Граница:** сравнение **только** команд `0` и `4` в стабильном окне `FETCH`/`LED_WRITE`, не по тактам, не по retirement, не формальная эквивалентность всего SoC. Остальные процессорные платформы (NEORV32, LiteX/VexRiscv, Rocket) не получили статус BOARD PASS в рамках данного этапа.

Следующий предлагаемый эксперимент: независимая реализация **NEORV32** с воспроизводимым функциональным протоколом UART+GPIO, сопоставлением требований и измерением ресурсов/тайминга, а не сравнением неидентичных потоков FETCH двух процессоров.

**Таблица ниже сохранена как исторический срез плана на 19.10.2026; её старые `NOT_RUN` не являются текущим статусом PicoRV32.**

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
