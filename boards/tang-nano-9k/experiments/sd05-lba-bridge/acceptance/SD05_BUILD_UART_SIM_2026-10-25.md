# SD-05 — build + integrated UART simulation checkpoint (25 October 2026)

**VERDICT: Python protocol PASS, production RTL compilation PASS, end-to-end UART behavioural simulation PASS, and Gowin BUILD PASS. Numerical STA and physical operation remain unverified. DO NOT program yet.**

## Build identity (operator terminal report)

- Local root: `C:\GitHub\Sipeed-FPGA-LAB05`
- Build run: `build/run_20261025_060319_470_56880c/`
- Candidate bitstream: `sd05_lba_bridge_nano9k.fs`
- Reported bitstream SHA-256:
  `BCA9FEF2F9786DDDB44286983CAE176921DEA66EF4E8FB791C677685FB373855`
- Actual local reports (not uploaded to GitHub):
  `work/impl/pnr/sd05_lba_bridge_nano9k_tr_content.html`,
  `work/impl/pnr/sd05_lba_bridge_nano9k.rpt.txt`,
  `work/impl/pnr/sd05_lba_bridge_nano9k.log`.
- Staged input hashes:
  `build/run_20261025_060319_470_56880c/input_sha256.csv`.

## Simulation operator evidence

```text
OK
SD05_UART_ROOT_FRAME_PASS: 523 bytes CRC and LBA echo
SD05_UART_BAD_REQUEST_PASS: CRC rejection without SD command
SD05_UART_SD_ERROR_PASS: CMD17 error propagated
SD05_UART_BRIDGE_TB_PASS: two 512-byte reads, CRC, LBA echo, errors, no extra bytes
C:\GitHub\Sipeed-FPGA-LAB05\boards\tang-nano-9k\experiments\sd05-lba-bridge\tests\tb_sd05_uart_bridge.v:218: $finish called at 1167130000 (1ps)
SD05_OFFLINE_GATE_PASS: Python + RTL + UART end-to-end simulation
```

## What was validated

1. Python CRC16-CCITT-FALSE, request packing, response validation and negative cases (4 tests passed in earlier local report).
2. Production top and actual SDHC core compile together.
3. End-to-end RTL with actual UART RX, top bridge and UART TX, and **mock SD reader**:
   - 523-byte response to LBA 17472, full 512-byte payload, echoed LBA/seq and CRC16.
   - CRC-corrupted request rejected without SD CMD17.
   - Mock CMD17 error returned in exactly 10 bytes.
   - Recovery and another full sector response with no extra bytes.
4. The initial duplicate-module compilation failure was corrected by compiling the real SD core in a **separate** production RTL gate and using the mock only for the UART behaviour test.

## Remaining gates (strict)

- **STA:** inspect the exact `*_tr_content.html` from this build for 27 MHz setup/hold violation counts, slack, TNS, unconstrained paths and clock definitions; check logic/FF/BSRAM against the `*.rpt.txt`. External UART RX and SD MISO IO timing still need explicit assessment.
- **Provenance:** compare the .fs SHA-256 on disk with the value recorded above. The existing candidate was built before the test-only build-list correction; no production RTL changes were made as part of that fix.
- **Physical tests only after STA:** explicit SRAM-only programming (never configuration Flash), then read LBA 0, LBA 64, LBA 17472 using Python; verify expected sector signatures and readback against independent PC captures. At most 2–3 bounded board checks before investigating physical link/timing.
- **No SD writes.** CMD24 and FAT metadata modifications are not part of SD-05. SD-04 remains frozen and separately hardware-tested.

**Scope:** behavioural UART protocol simulation PASS, not actual arbitrary-LBA physical read PASS. The mock sector contents are synthetic, not a capture of the user's SD card.
