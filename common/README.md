# Common contract

The shared peripheral **semantics**, test workloads, and report format belong here.
CPU-native bus protocols and CPU-specific clock/reset/debug logic do **not** belong here.
Each stage must implement an adapter for its bus that exposes the same software-visible MMIO contract. See [`mmio_v0_1.md`](mmio_v0_1.md).

## Портируемые демонстрации CPU

**[KonSol Cross-CPU Terminal Demos](cpu-terminal-demos/README_RU.md)** — семь цветных программ на C90 для различных процессоров. Хост-сборка проверена; версии для конкретных FPGA-SoC требуют UART-адаптера, памяти и загрузчика.
