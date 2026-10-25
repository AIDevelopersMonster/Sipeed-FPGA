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

## Artifact lifecycle — research evidence is not the product

**Project rule (25 October 2026):** successful interim steps (one sector,
another sector, a boot signature, temporary SHA-256 or a staging build)
are *evidence for a bigger engineering claim*, not automatically independent
releases, articles or permanent documents. Use three classes:

- **Reusable unit:** a self-contained FIFO/UART/SPI/CRC module with a
  documented interface, reproducible tests and reuse potential. Keep the
  source, stable test suite, version and an article only when an independent
  audience can use it.
- **Integrated result:** a complete demonstrable subsystem, e.g. the
  Tang Nano 9K SDHC CMD17/FAT32 file reader plus Python CLI. Publish a
  single cohesive README/article documenting the boundary, evidence,
  limitations and reproduction steps. Fold partial experiments into its
  development narrative instead of retaining separate user-facing releases.
- **Provisional experiment:** diagnostic transcripts, intermediate bitstreams,
  SHA receipts, synthetic fixtures, temporary branches and duplicated
  acceptance notes. Keep only while debugging/validating. On final acceptance,
  consolidate a minimal traceable evidence manifest and remove redundant
  provisional outputs in a reviewed cleanup. Do not delete existing work
  silently; preserve anything necessary to reproduce or audit the final claim.

A proposed standalone publication must answer **what new capability exists,
who needs it, and how another engineer reproduces it**. If these cannot
be answered convincingly, do not create a separate article.

### Release / cleanup gate

1. Finish the actual integration and state its measurable acceptance criteria.
2. Confirm reproducible tests and real-board measurements where claimed.
3. Freeze canonical sources, tests, pin constraints, tool versions and selected
   artifacts with SHA in a *single release manifest*.
4. Convert useful stage notes into the integrated documentation; archive
   special debugging evidence only when it materially explains a design choice.
5. Review and prune redundant intermediate files, duplicate receipts,
   abandoned branches and synthetic outputs after the release is verified.
   Keep the known-good prior release until the successor is proven.
6. Avoid generating new permanent receipts for every SD-06C micro-gate.
   Update the work package's concise status instead; physical writes remain
   explicitly opt-in on expendable media.

**SD direction:** SD-03/04/05/05.1/05.2 are supporting evidence for one
coherent read-only SDHC+FAT32 system. SD-06 is not a release until safe
end-to-end verification is achieved. A reusable FIFO may qualify as an
independent component with its own tests and article.
