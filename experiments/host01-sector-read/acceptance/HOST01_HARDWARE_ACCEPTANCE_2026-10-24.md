# HOST-01.1 — real microSD sector reads through FPGA: hardware acceptance

**Date:** 2026-10-24  
**Status:** `HOST01_BOARD_PASS` for **three physical 512-byte read-only CMD17 requests** made through Python → USB-UART → FPGA → SDHC SPI → microSD.  
**Evidence basis:** operator-supplied Windows/PowerShell/Python console transcript. No source card or binary captures were uploaded to this repository.

## Frozen accepted configuration and toolchain

- Board: Sipeed Tang Nano 9K, GW1NR-9C; 27 MHz system clock.
- HOST transport: USB–UART COM10, 115200 8N1; FPGA RX 18, TX 17.
- SD SPI: SCK 36, MOSI 37, CS 38, MISO 39.
- Bitstream: `experiments/host01-sector-read/build/run_20261024_170220_949_68d1e9/host01_sector_nano9k.fs` (local untracked build output, not copied into the repository).
- SHA-256 verified before programming: `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`.
- Gowin Programmer command returned success for **volatile SRAM** (`LAB04_SRAM_PROGRAM_COMMAND_PASS`); user code 0x0000AE6E, status 0x0003F020, 4.87 s.
- RTL mock: `HOST01_MOCK_512_PASS`; Python tests 5/5; Gowin build and strict internal STA PASS.
- STA: **0 Setup / 0 Hold violations**; Setup/Hold TNS **0 ns**; LUT 843; ALU 38; FF 466; BSRAM 4%; DSP/PLL 0.
- External SD MISO and UART asynchronous input timing are **not fully phase characterized** by the internal STA run.

## Hardware UART transactions (operator-provided transcript)

```text
Programming...: [#########################] 100%
User Code: 0x0000AE6E
Status Code: 0x0003F020
Cost 4.87 second(s)
LAB04_SRAM_PROGRAM_COMMAND_PASS: programmer reported exit 0; visually verify HDMI and LED.

python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 0 --output sector0.bin
HOST01_READ_PASS LBA=0 LENGTH=512 CRC=PASS
HEX[0:64]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
HOST01_SAVED: sector0.bin

python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 64 --output vbr.bin
HOST01_READ_PASS LBA=64 LENGTH=512 CRC=PASS
HEX[0:64]: eb 58 90 4d 53 44 4f 53 35 2e 30 00 02 40 00 08 02 00 00 00 00 f8 00 00 3f 00 ff 00 40 00 00 00 c0 3b c0 03 00 1e 00 00 00 00 00 00 02 00 00 00 01 00 06 00 00 00 00 00 00 00 00 00 00 00
HOST01_SAVED: vbr.bin

python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 17472 --output root.bin
HOST01_READ_PASS LBA=17472 LENGTH=512 CRC=PASS
HEX[0:64]: 42 20 00 49 00 6e 00 66 00 6f 00 0f 00 72 72 00 6d 00 61 00 74 00 69 00 6f 00 00 00 6e 00 00 00 01 53 00 79 00 73 00 74 00 65 00 0f 00 72 6d 00 20 00 56 00 6f 00 6c 00 75 00 00 00 6d 00 65 00
HOST01_SAVED: root.bin
```

## BPB consistency with SD-03 and SD-04

The first 64 bytes of the VBR above directly encode:

| FAT32 field | Value |
|---|---:|
| bytes/sector | 512 |
| sectors/cluster | 64 |
| reserved sectors | 2048 |
| FAT copies | 2 |
| sectors/FAT32 | 7680 |
| volume start (hidden sectors) | LBA 64 |
| FAT0 LBA = 64+2048 | 2112 (0x840) |
| first DATA LBA = 64+2048+2*7680 | 17472 (0x4440) |
| BPB root cluster | 2 |

These agree with previously operator-tested SD-03/SD-04 positions. First 64 bytes of MBR being zero is **not an error by itself**: the MBR partition table is at offsets 446–509 and the 55 AA signature at offsets 510–511.

The displayed root bytes include two FAT32 LFN entries consistent with the name `System Volume Information`; the prior SD-04 read reported short alias `SYSTEM~1`, attr `0x16`, first cluster 3. **Full LFN checksum and MBR signature are pending inspection of the actual full binary captures** via the separate read-only verification script.

## Acceptance scope and next gate

**PASS, strictly:** Physical FPGA SDHC CMD17 sector reads for LBAs 0, 64, 17472, transmitted as full 512-byte UART sector responses, validated by Python's transport-frame CRC16, with plausible VBR/root metadata and SHA/STA-qualified bitstream.

**Not certified:** independent byte-for-byte PC card-reader comparison, full MBR signature/partition records, all raw 512 bytes from binary file review, full LFN checksum, multi-sector stress, sustained throughput, error recovery, file writing, FAT32 updates or USB Mass Storage.

Next optional **read-only** evidence: `python experiments/host01-sector-read/tools/verify_captures.py --mbr sector0.bin --vbr vbr.bin --root root.bin`. Keep the originals unchanged. A separate user action must supply its console result to certify full MBR/BPB/LFN consistency.

**Do not replace or alter the accepted RTL or SRAM image in order to extend this evidence.** Any later write-capable SDHC module must be separate and explicitly tested on spare media.
