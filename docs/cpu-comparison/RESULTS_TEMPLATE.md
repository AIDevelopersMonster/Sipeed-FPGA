# LAB-06 comparison results / Протокол результатов (blank)

**STATUS: ALL COMPARATIVE RESULTS NOT MEASURED.** Replace placeholders only after a particular exact-source hardware campaign. Old PicoRV32 PiKoSoL full-HDMI results are **not** a CPU-only baseline.

| Field | PicoRV32 CPU-only | NEORV32 CPU-only | PicoRV32 minimal SoC | NEORV32 minimal SoC |
| --- | --- | --- | --- | --- |
| Status | NOT_RUN | NOT_RUN | NOT_RUN | NOT_RUN |
| Original source SHA | — | — | — | — |
| CPU ISA/generics | — | — | — | — |
| Toolchain/compiler | — | — | — | — |
| GW1NR-9C speed grade | — | — | — | — |
| Actual ROM/RAM | — | — | — | — |
| UART/GPIO/timer | — | — | — | — |
| FPGA bitstream SHA256 | — | — | — | — |
| LUT / ALU | — | — | — | — |
| FF / BSRAM / DSP | — | — | — | — |
| Setup/Hold min slack | — | — | — | — |
| Recovery/Removal min slack | — | — | — | — |
| Violated endpoints | — | — | — | — |
| W01 digest / cycles | — | — | — | — |
| W02 UART 256-byte result | — | — | — | — |
| W03 GPIO/Timer result | — | — | — | — |
| Board/date/log proof | — | — | — | — |
| Deviations/risks | — | — | — | — |

## Block comparison table / Сравнение типовых блоков

| Block | Common behavior and RTL revision | Pico native SoC | NEORV32 native SoC | Shared-IP + Pico adapter | Shared-IP + NEORV32 adapter |
| --- | --- | --- | --- | --- | --- |
| ALU32 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | Independent educational comparison | Independent educational comparison |
| Regfile 32×32 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | Port/latency equivalence required | Port/latency equivalence required |
| RV32I decode | NOT_RUN | NOT_MEASURED | NOT_MEASURED | Independent vectors | Independent vectors |
| UART8N1 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | NOT_RUN | NOT_RUN |
| GPIO6 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | NOT_RUN | NOT_RUN |
| Timer32 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | NOT_RUN | NOT_RUN |
| SPI mode 0 | NOT_RUN | NOT_MEASURED | NOT_MEASURED | NOT_RUN | NOT_RUN |
| SD CMD17 (read-only) | NOT_RUN | NOT_MEASURED | NOT_MEASURED | NOT_RUN | NOT_RUN |

**Reviewer rule:** If exact resources, timing, firmware identity and same workload evidence are missing, the row remains NOT_RUN / NOT_MEASURED. Record an actual non-fit result as a result, never as a blank success.
