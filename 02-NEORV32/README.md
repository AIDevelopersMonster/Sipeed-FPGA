# 02 — NEORV32

**Status: plan / no implementation or board evidence in this release.**

Target board: **Tang Nano 9K** (GW1NR-9). Source processor: [`stnolting/neorv32`](https://github.com/stnolting/neorv32), see `../sources.lock.json`.
Reference board port: [`jimmyw/tang_nano_9k_neorv32`](https://github.com/jimmyw/tang_nano_9k_neorv32).

## Proposed research

1. Select a minimal documented RV32I configuration and inspect exact on-chip resource utilization.
2. Use a tiny boot program before integrating external flash/user-flash/Zephyr.
3. Map an adapter to common MMIO registers (`../common/mmio_v0_1.md`) or record reason for revised map.
4. Add UART, GPIO, timer and test markers; simulate independently, then perform PnR/board check.
5. Only afterwards evaluate instruction flash execution, traps, interrupts and Zephyr as **separate configurations**.

**Non-claim:** NEORV32 + Zephyr is demonstrated by an external project, not by our current implementation. Vendor user-flash drivers are board-dependent and must be isolated; upstream VHDL is not a drop-in substitute for Gowin clock, IO or flash peripherals.

## Later directory contract

- `rtl/` CPU wrapper and MMIO adapter
- `firmware/` programs and linker script
- `tests/` simulation/testbench
- `constraints/` board-specific IO + timing
- `reports/` raw tool reports (not committed if bulky)

Create these folders when there are actual files rather than filling them with empty claims.
