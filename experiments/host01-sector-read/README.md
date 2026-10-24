# HOST-01 — PC/Python UART → read-only microSDHC sector via FPGA

**Status (2026-10-24): HOST01_BOARD_PASS for LBA 0, 64 and 17472 (3/3 512-byte physical sectors; UART transport CRC16 PASS; MBR and VBR 55 AA signatures verified by operator). RTL simulation PASS, Python 5/5, Gowin PnR PASS, internal STA 0/0 and TNS 0.** See [operator-supplied STA acceptance](acceptance/HOST01_STA_ACCEPTANCE_2026-10-24.md). No SD writes or filesystem updates.

## Architecture: small independent modules

```text
PC Python → USB-UART
             ↓
    uart_rx_8n1.v      (shared UART core)
             ↓
    sync_fifo.v        (RX 8 bytes, shared FIFO core)
             ↓
    host01_sector_engine.v  (this experiment only)
             ↓ SD start/lba/done/peek (512-byte synchronous BSRAM)
    lab05_sd_read_sector.v + lab05_spi_byte.v (shared, byte-identical read-only SDHC core)
             ↑
    host01_sector_engine.v
             ↓
    sync_fifo.v        (TX 8 bytes, shared FIFO core)
             ↓
    uart_tx_8n1.v      (shared UART core)
             ↓
           PC Python
```

Transport CRC is an **independent** `cores/crc16-ccitt/v1/rtl/crc16_ccitt_byte.v`; it is distinct from the original SPI data CRC in SDHC. The main top is purely composition; existing HOST-00, SD-03/04 and PiKoSoL are unchanged.

## Wire protocol v1

Fixed request (8 bytes): `A5 01 <LBA32 little-endian> <CRC16 little-endian>`, with CRC16/CCITT-FALSE (init FFFF, polynomial 1021, no reflection) over the **first six** bytes.

Successful response (521 bytes): `5A 81 00 <LBA32 LE> <512 raw sector bytes> <CRC16 LE>`; CRC over the **first 519** response bytes. Error response (9 bytes): `5A 81 <nonzero error> <LBA32 LE> <CRC16 LE>`. The SDHC error codes are forwarded, with `FD` reserved for engine SD-read timeout. Request corruption is silently rejected; no response. One request at a time; no pipelining. This is a small educational protocol, not an industrial framing/flow-control standard.

At 115200 8N1 the response alone occupies about 45 ms of wire time (not including SDHC initialization and SPI read). Python's default transaction timeout is 20 seconds. The SPI core stays at the already used ~211 kHz.

## Local tests (Windows PowerShell)

The tests and synthesis both depend on the *independent* shared UART/FIFO/CRC/SDHC cores. No copied Verilog in the experiment.

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git fetch origin
git switch --track origin/agent/host01-uart-sdhc-readonly
& .\experiments\host01-sector-read\test.ps1
& .\experiments\host01-sector-read\build.ps1
```

A specific generated candidate has now passed the local internal STA/SHA gate (see acceptance receipt). For **that exact SHA-256 only**, proceed to the existing SRAM-only Gowin programmer, then test one LBA at a time. If the bitstream is rebuilt or RTL changes, repeat STA/SHA. Physical SD MISO timing is not fully characterized.

## Python read-only access: three physical sector reads verified

```powershell
python -m pip install pyserial
python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 0 --output sector0.bin
python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 64 --output vbr.bin
python .\experiments\host01-sector-read\tools\host01_sector.py --port COM10 --lba 17472 --output root.bin
```

`COM10` is the previously observed port; check current enumeration. The LBA values 64 and 17472 were confirmed for the card from SD-04. These three sector reads **have been verified through HOST-01** using the STA-accepted candidate; see [hardware acceptance receipt](acceptance/HOST01_HARDWARE_ACCEPTANCE_2026-10-24.md). Full binary-file structural inspection and independent card-reader comparison remain separate acceptance gates. The script prints the first 64 bytes as HEX and optionally checks a reference image via `--compare-image`; the image is read locally and is **never written**.

## Validation limitations

The first RTL iteration uses the existing 512-byte **synchronously read** sector RAM. The engine inserts two dead cycles after changing `peek_addr` to avoid stale data. UART queues have 8 entries; host requests must be serialized. The link currently does not report UART framing errors or FIFO overflow to Python. This is not filesystem access, FAT32 writing or USB mass storage.

Important: a passing Icarus test does **not** prove new physical build, STA, MISO timing, correct external card contents, or sustained multi-sector traffic. Each additional stage needs its own acceptance.

## Hardware acceptance and published evidence

[HOST-01 hardware acceptance (2026-10-24)](acceptance/HOST01_HARDWARE_ACCEPTANCE_2026-10-24.md): three live physical 512-byte microSD sector responses over FPGA UART, all transport CRC PASS, valid FAT32 BPB data and prior SD03/04 layout consistency. Bitstream SHA-256: `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`. **No writes to microSD**.

**Final sector-capture signature check:** `sector0.bin` 512 bytes ending `55 AA`; `vbr.bin` 512 bytes ending `55 AA`; `root.bin` 512 bytes ending `00 00` (normal for a directory sector). These findings are recorded in the [HOST-01 hardware acceptance receipt](acceptance/HOST01_HARDWARE_ACCEPTANCE_2026-10-24.md). The next FAT32 parsing phase is independent and strictly read-only.
