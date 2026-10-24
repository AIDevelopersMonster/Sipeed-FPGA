# HOST-01 — local STA acceptance / physical test handoff

**Date:** 2026-10-24. **Evidence:** user's Windows PowerShell logs. **Status:** RTL SIM PASS, Python unit tests 5/5, Gowin PnR PASS, **internal STA PASS**, physical board test pending.

## Isolated local build

- Run directory: `C:\GitHub\Sipeed-FPGA-LAB05\experiments\host01-sector-read\build\run_20261024_170220_949_68d1e9`
- Bitstream: `host01_sector_nano9k.fs`
- SHA-256: `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`
- Input snapshot manifest: `input_sha256.csv` inside the above local run. Source snapshots from the canonical UART/FIFO/CRC/SDHC cores and this experiment's small RTL modules.

## User-provided test evidence

```text
HOST01_MOCK_512_PASS: LBA=00004440 512 bytes CRC16 verified
Ran 5 tests in 0.007s
OK
HOST01_LOCAL_SIM_PASS

HOST01_BITSTREAM_CANDIDATE: C:\GitHub\Sipeed-FPGA-LAB05\experiments\host01-sector-read\build\run_20261024_170220_949_68d1e9\host01_sector_nano9k.fs
HOST01_SHA256: 5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4
HOST01_BUILD_ONLY: run strict STA gate, never program without acceptance.

HOST01_SHA256_PASS: 5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4
HOST01_Setup_VIOLATIONS: 0
HOST01_Hold_VIOLATIONS: 0
HOST01_Setup_TNS_NS: 0
HOST01_Setup_TNS_ENDPOINTS: 0
HOST01_Hold_TNS_NS: 0
HOST01_Hold_TNS_ENDPOINTS: 0
Logic: 905/8640 (11%); LUT 843; ALU 38; FF 466/6480 (8%)
BSRAM: 4%; DSP 0%; PLL 0/2
HOST01_STA_PASS: internal clk27 timing, SHA256, pins.
```

Internal timing paths shown in report have Setup slacks from +12.908 ns to +14.715 ns (first eight paths only; not a claim for an unlisted global minimum). The `check_sta.ps1` explicitly warns that asynchronous UART RX input and external SD MISO return path are not fully phase-characterized.

## Safe physical next steps (NOT yet executed)

- Verify exactly the SHA-256 above and dry-run `01-PicoRV32/lab04/tools/program_lab04_sram.ps1 -Bitstream <fs>` (no `-Program`).
- Explicitly load to **volatile SRAM only** with `-Program`, never write configuration Flash.
- With the original SD card inserted and COM port available, use Python's read-only `--lba 0` request. On success, also read LBA 64 (FAT32 BPB) and LBA 17472 (root), preserving raw 512-byte captures to local PC files.
- Accept actual `HOST01_BOARD_PASS` only when operator shares verified physical 512-byte output and CRC success; ideally cross-check meaningful MBR/VBR/ROOT bytes against independent SD-04 observations or a PC card reader. If two or three obvious physical tests fail, record and stop, without speculative rewrites.

**Nonclaims:** This is not yet a board-pass receipt and does not demonstrate an arbitrary sector read from physical microSD through this new HOST-01 bitstream. SD writes, FAT32 updates, USB-MSC and higher-speed multi-sector transfers are not implemented.
