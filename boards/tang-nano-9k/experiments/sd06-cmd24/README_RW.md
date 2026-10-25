# Standalone SDHC PC / FPGA read-write prototype

**Purpose:** reusable SD subsystem for a future larger PiKoSoL. Tang Nano 9K is the independent test bench, not the final CPU+HDMI+SD target.

## Confirmed vs pending

- SD-05 read-only bitstream: real hardware PASS on two FAT32 SDHC cards. A 131073-byte five-cluster file matched SHA-256.
- SD-06B CMD24 byte-engine: offline Python and SPI-byte model PASS.
- Merged PC UART / CMD17 / CMD24 / CMD17 verification prototype: SOURCE CREATED, **full integration simulation, Gowin PnR/STA, and hardware write NOT YET PASS**.
- FPGA writes are **disabled by default** using compiled constant region 0..0. Do not program the merged prototype before complete qualification.

## Single PC interface

Read packets are backward compatible with SD-05. Writes use frame
A5 57 seq LBA32_LE old512 new512 CRC16_LE (1033 bytes).
FPGA checks frame CRC and 512 old-sector bytes using CMD17 before allowing CMD24. It then reads the sector again via CMD17 and verifies all new bytes. Write response: 5A 57 seq LBA32_LE status CRC16_LE (10 bytes). Errors are fail-closed.

PC command line: tools/sd_rw.py. This requires pyserial and Windows COM.

Read sector today using **accepted SD-05 firmware**:

    python .\boards\tang-nano-9k\experiments\sd06-cmd24\tools\sd_rw.py --port COM10 read --lba 0 --out .\sd_mbr.bin

Existing FAT32 read-only file browser remains in sd05-lba-bridge/tools/fat32_host.py. It supports info, ls, get. Raw sector writing does NOT create a FAT32 file.

## Development verification

    cd C:\GitHub\Sipeed-FPGA-LAB05
    git pull --ff-only
    .\boards\tang-nano-9k\experiments\sd06-cmd24\test.ps1
    .\boards\tang-nano-9k\experiments\sd06-cmd24\build_rw.ps1

The separate build script copies source and constraints into an isolated directory and runs Gowin, without programming FPGA. It uses compiled WRITE_FIRST_LBA=0 WRITE_LAST_LBA=0: no writes possible. First independently review full-frame UART simulation, synthesized resource reports, STA and bus arbitration.

## Physical write gate (NOT YET AUTHORIZED)

Only on a **disposable SDHC card** with full external backup and identified scratch LBA not intersecting any partition/metadata. Authorize exactly one confirmed sector in a separately reviewed experiment build; compile and retain immutable input hashes, run SRAM only, validate original preimage, send CMD24, CMD17 readback, compare SHA-256 and restore backup. Writing any sector of a valuable FAT32 card is prohibited.

Future CLI after physical qualification:

    python sd_rw.py --port COM10 write --lba 12345 --data new512.bin --preimage old512.bin --expect-sha256 HASH --allow-lba 12345 --confirm WRITE-TEST-CARD-LBA-12345

12345 is only an **example**, not a proven safe sector.

## PiKoSoL feasibility measurement

Record standalone combined read/write module LUT, FF, BSRAM, Fmax and STA, then only after that compare to resource use of CPU+HDMI PiKoSoL. A 20K/25K device is a candidate, not a measured integration result. No separate SD-06 micro-releases: keep one final module README and reproducible tests.
