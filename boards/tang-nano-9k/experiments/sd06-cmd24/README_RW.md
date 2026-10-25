# Standalone SDHC PC / FPGA read-write prototype

**Purpose:** reusable SD subsystem for a future larger PiKoSoL. Tang Nano 9K is the independent test bench, not the final CPU+HDMI+SD target.

## Confirmed vs pending

- SD-05 read-only bitstream: real hardware PASS on two FAT32 SDHC cards. A 131073-byte five-cluster file matched SHA-256.
- SD-06B CMD24 byte-engine: offline Python and SPI-byte model PASS.
- Merged PC UART / CMD17 / CMD24 / CMD17 verification: **offline PASS** (16 Python tests, integrated UART mock, CMD24 SPI mock). **Standalone full-RW Gowin PnR and internal STA PASS** on 9K; hardware CMD24 write is still NOT TESTED.
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

## End-to-end acceptance gate (one command)

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git pull --ff-only
$sd = '.\boards\tang-nano-9k\experiments\sd06-cmd24'
& "$sd\test.ps1"
```

The test script now includes `tb_sd06_rw_uart.v`, exercising real UART
receiver/transmitter and the combined RTL top with isolated CMD17/CMD24 mock
modules. The simulated transfer covers read, write with 512-byte preimage,
verified readback, and denial of stale preimage, corrupt frame CRC, unapproved
LBA, CMD24 rejection and corrupted readback. Existing Python and CMD24
byte-level SPI tests remain included. The integration test **passed on the operator machine on 2026-10-25**,
including read/write/readback and all specified fail-closed cases. This is a
mock SD-card test, not physical-media qualification.

**Program status:** only the previously accepted SD-05 read-only bitstream is
approved for hardware use. `build_rw.ps1` is an isolated *build-only*
operation. New physical writes require explicit confirmation for a different
backed-up sacrificial card, after the integrated test and PnR/STA have passed.

## Verified full-RW Gowin 9K measurement — 2026-10-25

**Evidence:** `SD_RW_9K_REPORTS.zip` from operator's isolated run
`build/measurement_20261025_082230_205` with exact source SHA-256
manifest `inputs.csv`, Gowin CLI log, PnR report and STA HTML.

| Metric | PnR / STA observation |
|---|---|
| Device / tool | GW1NR-LV9QN88PC6/I5; Gowin V1.9.9 Beta-4 Education |
| Full controller logic | **1937 / 8640 (23%)**; includes 1459 LUT, 94 ALU, 64 RAM16 |
| Registers | **662 / 6693 (10%)**; 660 logic FF, 2 I/O FF |
| BSRAM | **3 SDPB (12%)** |
| CLS | **1180 / 4320 (28%)** |
| Clock | single fabric `clk27` 27.000 MHz, period 37.037 ns |
| Calculated max frequency | **57.230 MHz** (STA internal clock path) |
| Worst setup slack | **+19.564 ns** |
| Worst hold slack | **+0.443 ns** |
| Worst recovery / removal | **+33.268 ns / +2.563 ns** |
| Setup / hold violated endpoints | **0 / 0**; TNS **0 / 0** |
| Paths / endpoints analyzed | **2874 / 2624** |
| PLL / DSP | **0 / 0** |
| Ports | **14** |

**Meaning:** the standalone complete CMD17 + CMD24 + UART controller
*fits Tang Nano 9K* and meets the internal 27 MHz timing constraint in the
examined implementation. This measurement intentionally retains the full
write datapath by using a synthetic constant LBA in a **measurement-only**
wrapper. Its configuration files must **never** be used for programming a
real FPGA; the script deletes programming outputs.

**Important limitations and warnings:** the SDC constrains the 27 MHz input
clock only; the SPI SCK-to-MISO external timing and UART input/output timing
are not independently characterized. Gowin reported four bounded 11/10-to-9
bit width truncations in the merged top and one RAM-style attribute warning
in the writer. These warnings did not prevent synthesis/PnR but require
careful RTL and inferred-RAM review before physical write approval.
The standalone statistics **do not** establish whether PiKoSoL CPU + HDMI +
graphics + RW can fit simultaneously on 9K.

**Remaining hardware acceptance:** preserve qualified SD-05 image, validate
merged *write-disabled* RTL read-only against a real SD card, then qualify
one explicitly approved LBA on a disposable fully backed-up SDHC card for
write and independent CMD17 readback. No RW hardware PASS is claimed yet.

## Hardware qualification: approved first gate (merged read-only)

2026-10-25: Four Gowin EX3791 address-width warnings were addressed by
explicit modulo-512 address calculations; the unsupported payload RAM-style
hint was removed. Rebuild is **required**; the older PnR measurements are
a baseline, not proof that the modified RTL remains equivalent.

The first physical gate must **not** write any card. It builds the combined
controller with both WRITE_FIRST_LBA and WRITE_LAST_LBA equal to zero. With
these constants, the hardware writer is intentionally unavailable; this
gate checks combined RTL CMD17 + UART and pin/timing compatibility.

From the existing feature branch:

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git pull --ff-only
$sd = '.\boards\tang-nano-9k\experiments\sd06-cmd24'
& "$sd\hw_read_gate.ps1"
```

The default runs all offline tests, builds a fresh isolated bitstream and
checks STA **without programming**. After reviewing the .fs path, exact
SHA-256 and passed internal timing, an explicitly authorized SRAM-only test
on a *read-only / preserved* SD card is:

```powershell
& "$sd\hw_read_gate.ps1" -Program -Port COM10 -Lba 0
```

This reruns the build (isolated new directory) and uses Gowin Programmer
operation_index 2: **volatile SRAM**, not configuration flash. It then
saves the returned 512-byte LBA 0 to the build directory, prints SHA-256
and never overwrites an existing sector file. This test does **not**
exercise CMD24. Do not load measurement-only files or any
write-enabled bitstream.

**Write gate is deliberately not published as an automated programming
command.** Before ever releasing a write-enabled image, independently
validate a disposable SDHC card's complete partition table, sector count,
scratch-LBA ownership and backup, and verify physical CMD24/SPI timing.
Do not select a random LBA on an existing FAT32 volume.
