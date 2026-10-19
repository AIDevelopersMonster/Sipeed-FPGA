# Protocol: evidence and measurements

## Gates (never substitute one for another)

| Gate | Evidence | Necessary for |
|---|---|---|
| `SOURCE_READY` | source tree, pinned SHA, hashes | reproducing code |
| `MODEL_PASS` | assembler + separate Python RV32I interpretation | sanity check of firmware |
| `RTL_PASS` | `iverilog/vvp` transcript for CPU, bus and UART | behavior in simulation |
| `PNR_PASS` | bitstream, utilization, clock constraint, STA | viable FPGA configuration |
| `BOARD_PASS` | photographed wiring, UART log, reset/reboot sequence | real hardware execution |
| `BENCHMARKED` | same workload and complete metadata | comparative numerical analysis |

The first release is at `MODEL_PASS` only; no working real hardware is asserted.

## Required measurements

- Board, exact chip/package, source commit, RTL parameterization and compiler/tool versions.
- LUT4 (or FPGA-native equivalent, specify denominator), FF, block RAM, DSP, other hardened resources.
- Fmax and requested constrained clock, STA slack, warnings, build runtime and peak RAM of build host.
- Latency in clocks, throughput, and behavior under UART / memory contention for an agreed workload.
- Data transfer tests and independent LED/UART readback/log evidence.

### Comparison caveats

Vendor LUTs, logic elements and cell counts are not interchangeable. Absolute timing across 27 MHz Nano9K and 50 MHz Primer25K is not controlled for platform; compare cycles, cycles/op, resource classes and (when defensible) normalized metrics separately. Avoid treating the unoptimized demo as a benchmark of the processor architecture.
