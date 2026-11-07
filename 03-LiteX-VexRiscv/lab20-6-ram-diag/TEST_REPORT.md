# LAB-20.6 v0.1.0 — Test receipt (offline only)

**Date:** 2026-11-07. **Status:** `BUILD_PASS / RV32_SIM_PASS / WINDOWS_COM25_UNTESTED / BOARD_TEST_PENDING`.

## Build inputs and constraints

- Compiler: LLVM Clang 17 `--target=riscv32-unknown-elf -march=rv32i_zicsr -mabi=ilp32 -mno-relax`.
- Linker: LLD `-m elf32lriscv`, entry `0x40010000`, no libraries, no C runtime, no stack, no compressed instructions.
- Source: `snapshot.S`; linker: `linker.ld`.
- Raw image: 740 bytes (`185` × 32-bit memory writes).
- Raw image SHA-256: `def94e225021f654258cd2760a32c63343a0ade98b4f770882e63a2f17255a0e`.
- ELF SHA-256: `c25196b0b51776ad3cf9450128ee1f6ac850d331ac543bac6777f90150ba9e36` (compiler-specific; target BIN is canonical).
- Program 740 bytes fits strictly below `0x40011000` snapshot area. The build linker asserts the size cap.

## Tested in the independent RV32I simulator

`python3 test_emulator.py` executed actual assembled binary instructions, not a high-level functional mock:

1. **TX FIFO initially empty** (`txempty=1`) — PASS. Pre-print sample records `1`, post-print sample records `0` under the fixture's FIFO model.
2. **TX FIFO initially nonempty** (`txempty=0`) — PASS. Pre-print sample records `0`, post-print sample remains `0`.
3. **11 read-only CSR samples** read from the prescribed addresses, with CPU-specific  CSR 0xBC0/0xFC0 — PASS.
4. UART `rxtx` writes occur **only after** first snapshot is complete (marker at `0x40011034`) — PASS.
5. Absolutely no MMIO writes except to `0xF0003000`, and no SDRAM writes outside `0x40011000..0x4001103B` — PASS.
6. Text report includes all registers, `TXEMPTY_AFTER_PRINT` and the final HOLD message — PASS.
7. All lines of `load_mem_write_only.txt` decode exactly to each word of canonical `snapshot.bin` at sequential SDRAM addresses — PASS.
8. Whole ELF is RISC-V 32-bit little-endian with entry `0x40010000`, verified using `readelf` and `llvm-objdump` — PASS.

Typical simulator output:

```text
PASS txempty_preprint=1 steps=2,101,573, bytes_TX=420, mmio_reads=801, snapshot_data_verified=True
PASS txempty_preprint=0 steps=2,101,573, bytes_TX=420, mmio_reads=801, snapshot_data_verified=True
PASS binary+commands+memory bounds+all UART text+snapshot-before-print
```

**Model limitations:** The simulator treats the TX FIFO as ready for writes, and `txempty` as busy after the first byte, and uses fixture values for machine CSRs. It is **not** a timing/RTL simulation of LiteX VexRiscv, UART, SDRAM controller, or real FPGA. Instruction-level functional checks do not establish hardware compatibility. Delay timing is not formally guaranteed.

**Windows loader:** PowerShell source was reviewed and published; it was not executed against Windows COM25 during this offline test. It performs an explicit SHA-256 check and SDRAM readback before optional boot. `-Boot` is opt-in.

## Acceptance criteria on physical board

- Script connects to the actual BIOS prompt and returns `PASS` on SDRAM readback for all 740 bytes.
- With explicit `boot 0x40010000`, UART prints `PiKoSoL LAB20.6 RAM-only snapshot BEFORE UART output` and 11 pre-print entries, then `TXEMPTY_AFTER_PRINT`.
- Copy both `TXEMPTY` and `TXEMPTY_AFTER_PRINT` values **as measured**; do not replace with modeled values.
- Program ends in HOLD and physical hardware RESET returns to factory LiteX BIOS without Flash modification.

Until then status remains `BOARD_TEST_PENDING`.

## Uploader hotfix v0.1.1 — 2026-11-08

Reported physical-host result: `TIMEOUT waiting for [litex>]. Received:  litex>` during the initial boot-prompt handshake, **before any SDRAM write**. Primary source `litex/soc/software/bios/readline.h` at `b05c3069` defines `PROMPT "\e[92;1mlitex\e[0m> "`, so the text is interrupted by ANSI SGR escape codes that the original script failed to normalize.

Corrective change: strip ANSI CSI sequences in `Read-Until` before looking for `litex>`, retain a raw code-point dump in timeout diagnostics, and introduce `-Probe` that does not issue memory commands.

Regression test `test_upload_protocol.ps1` uses **the functions parsed from the actual uploader source** and tests the ANSI prompt and SDRAM hex dump readback, including rejection of a corrupted byte. It must be run in PowerShell on the Windows operator host; a PowerShell runtime is **not** available in the current build environment. The firmware code and its SHA-256 are unchanged. Status: `ROOT_CAUSE_CONFIRMED_BY_LITEX_SOURCE / STATIC_CHECK_PASS / WINDOWS_PROBE_PENDING / BOARD_UPLOAD_PENDING`.

Source: [LiteX historical readline.h](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/readline.h).