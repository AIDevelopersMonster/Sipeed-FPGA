# PiKoSoL LAB-20.6 — SDRAM readback hardware verification

**Date:** 2026-11-08 (operator-supplied Windows terminal log).  
**Board:** Sipeed Tang Nano 20K, original LiteX BIOS, VexRiscv_Min (factory SoC).  
**Host:** PowerShell 7, COM25, 115200 baud.  
**Program:** `snapshot.bin`, 740 bytes / 185 RV32 instruction words, load address `0x40010000`.  
**Canonical SHA-256 (host image):** `def94e225021f654258cd2760a32c63343a0ade98b4f770882e63a2f17255a0e`.

## Proven by operator's terminal

- Git branch checked out at commit `5ac5a814354e546a53248733db844e727a2ee997` (loader v0.1.2, offline test v0.1.3).
- **Offline protocol test PASS**: ANSI LiteX prompt across 5 chunks; generic 16-byte readback parsing; corrupt byte rejection; literal physical-board response parsing; CR-only, LF-only, CRLF, single-line and last 4-byte readback; negative controls for wrong address, missing header and wrong mock command.
- **Physical SDRAM write:** prior session transmitted all 185 `mem_write` commands using `upload.ps1 -PortName COM25 -Upload`. The first readback yielded the expected first 16 bytes; a host-side line-boundary parsing error prevented full verification in that session.
- **Physical, read-only verification:** `upload.ps1 -PortName COM25 -VerifyOnly` received the LiteX prompt and then read the previously uploaded program at `0x40010000`. All readback chunks match the canonical binary **byte for byte**, including the final 4-byte chunk. The readback session performs no `mem_write`, no `boot`.

## Operator terminal evidence (exact excerpts)

```text
PS ...> pwsh -NoProfile -File .\test_upload_protocol.ps1
PASS: byte-stream ANSI colored LiteX prompt recognized across 5 chunks.
PASS: 16-byte SDRAM dump readback parsed and verified.
PASS: corrupt readback rejected before boot.
PASS: real flattened board response matched canonical BIN.
PASS: CR-only, LF-only, CRLF, flattened and final 4-byte block.
PASS: wrong address and missing header rejected.
PASS: mock rejects a request inconsistent with the fixture.
PASS: uploader v0.1.3 protocol regression finished, no COM or writes.

PS ...> pwsh -NoProfile -File .\upload.ps1 -PortName COM25 -VerifyOnly
PiKoSoL LAB-20.6: 740 bytes, 185 words, SHA256 def94e225021f654258cd2760a32c63343a0ade98b4f770882e63a2f17255a0e
BIOS prompt detected. VERIFY ONLY: no SDRAM writes and no boot.
Full SDRAM readback, 16-byte blocks...
Readback verified 128/740 bytes
Readback verified 256/740 bytes
Readback verified 384/740 bytes
Readback verified 512/740 bytes
Readback verified 640/740 bytes
Readback verified 740/740 bytes
PASS: 740 bytes SDRAM readback match SHA256-controlled binary; NO WRITES / NO BOOT.
Verified existing SDRAM image. BIOS remains active; no writes or boot.
```

## Evidence boundaries

**Verified on real board:** BIOS UART communication, successful SDRAM write sequence, full 740-byte SDRAM readback matching the expected compiled image, verified loader's no-write readback mode. The original FPGA configuration/Flash was not reprogrammed.

**Not yet verified:** instruction fetch/execution by VexRiscv from `0x40010000`, the user-program UART output, CSR snapshot correctness at `0x40011000`, before/after UART self-observation hypothesis, the final HOLD state and physical reset. No hardware execution receipt is inferred from SDRAM readback.

**Status:** `LAB20_6_SDRAM_READBACK_HARDWARE_PASS / RV32_APP_BOOT_PENDING`.

## Next gated experiment: explicit program launch

After ensuring UART terminal is connected to COM25 and power has not been cycled since the verified readback:

```text
litex> boot 0x40010000
```

**No automatic BIOS return.** After the report appears, the program enters HOLD; press the board's physical RESET to return to the factory BIOS. If the console becomes unresponsive or no report is printed, collect what appeared, use physical RESET, and do **not** attempt to recover by writing configuration Flash.

Relevant sources: [program and loader](README.md); [offline test report](TEST_REPORT.md); [historical LiteX boot.c](https://github.com/enjoy-digital/litex/blob/b05c3069/litex/soc/software/bios/boot.c).
