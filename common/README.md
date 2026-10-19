# Common contract

The shared peripheral **semantics**, test workloads, and report format belong here.
CPU-native bus protocols and CPU-specific clock/reset/debug logic do **not** belong here.
Each stage must implement an adapter for its bus that exposes the same software-visible MMIO contract. See [`mmio_v0_1.md`](mmio_v0_1.md).
