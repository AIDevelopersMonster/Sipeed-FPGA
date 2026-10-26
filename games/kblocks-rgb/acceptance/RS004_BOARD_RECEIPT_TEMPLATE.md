# RS-004 K-BLOCKS RGB | Operator acceptance receipt / Шаблон квитанции

**STATUS: NOT RUN. All PASS fields start as unknown. Do not pre-mark.**

Date/time: `NOT_RECORDED`
Board: `Tang Nano 9K GW1NR-9C` (read actual marking)
Git source revision: `NOT_RECORDED`
Icarus PASS output: `NOT_RUN`
Gowin release/version: `NOT_RECORDED`
PnR FIT: `NOT_RUN`
Full STA report path + constrained/unconstrained path summary: `NOT_RECORDED`
Bitstream filename/path/bytes: `NOT_RECORDED`
Candidate SHA-256: `NOT_RECORDED`
UART COM / baud: `NOT_RECORDED` / `115200 8N1`
FPGA programming: **SRAM ONLY**. Flash: **FORBIDDEN**.

| Test | Expected | Observed / PASS / FAIL |
| --- | --- | --- |
| 01 JTAG/HDMI | Stable 640x480, field, seven-segment lines counter 00, next preview, palette | NOT_RUN |
| 02 Game | Left/right rotate/down; piece locks, at least one row clears, line counter increments | NOT_RUN |
| 03 Top-out/restart | Stack reaches top, Game Over visual signal, start fresh via P/Space | NOT_RUN |

Do not claim BOARD PASS based on testbench/synthesis alone. Do not publish a release or add the .fs to WebUSB until physical board PASS and exact-file SHA are recorded.
