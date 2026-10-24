# HOST-SD-01 — Python/SoC block-device bridge over the FPGA SDHC core

**Decision / architecture reservation — 2026-10-24. Status: planned, NOT an implemented host interface or write-capable bitstream.**

## Goal

Preserve the teaching path `SD-01 → SD-04` (autonomous HDL examination of the MBR, BPB and FAT32 directories) while enabling an independent **host-controlled 512-byte sector access** mode for Python on a PC and for a future processor/SoC. The transport and FAT32 layer must remain separable from the reusable SDHC block service.

**Direct answer:** A Python script can already read/write files when the microSD is inserted in an ordinary PC card reader, without FPGA. It cannot currently issue arbitrary sector reads or writes to the card *through* the SD-04 FPGA. Present SD-04 only transmits UART diagnostic lines (`uart_tx`, pin 17), and its frozen `lab05_sd_read_sector` only supports CMD17 READ with a one-sector 512-byte BSRAM. There is no UART RX protocol and no CMD24 write engine.

## Physical transport on Tang Nano 9K

- Board's BL702 supplies USB-JTAG and USB-UART over USB-C.
- Known FPGA → PC UART TX: FPGA pin **17**, already used in SD-03 and SD-04.
- Candidate PC → FPGA UART RX: FPGA pin **18**, supported by the Sipeed BL702 debugger mapping; **not yet constrained or wired in our `top`**. Check the exact PCB revision and USB-UART enumeration before qualifying this path.
- FPGA ↔ card SPI: SCK **36**, MOSI **37**, CS **38**, MISO **39**; system clock 27 MHz.
- Initial transport: **pyserial → COM port → UART RX/TX on FPGA**, full duplex. This is separate from the JTAG programmer and does **not** turn the FPGA into a native USB Mass Storage Class (MSC) card reader.

Sipeed references (for review; no reliance on undocumented USB access):
- https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-9K/Nano-9K
- https://github.com/sipeed/RV-Debugger-BL702
- https://dl.sipeed.com/fileList/TANG/Nano%209K/2_Schematic/Tang_Nano_9k_3672_Schematic.pdf

## Architecture: one block service, several clients

```text
                 PC (Python, pyserial)
                     |   UART frames
                     v
             UART RX/TX + host framing
                     |   READ512 / WRITE512 (later)
                     v
    +-------------------------------------------+
    |  sector-request arbiter (single owner)    |
    |  - host-controlled mode                   |
    |  - autonomous MBR/FAT32 laboratory mode   |
    +-------------------------------------------+
                     |
       v1: existing READ CMD17 + 512B BSRAM
       v2: optional WRITE CMD24 + 512B staging
                     |
                   SPI master
                     |
                   microSDHC
```

On-PC filesystem: Python / host OS library translates files and FAT32 metadata to sectors, sending *block* requests through UART. On-FPGA filesystem: educational FSM modules can independently parse MBR/BPB/FAT directories using the same physical block service. The core must not contain two competing SPI masters.

For a **SoC with native SDMMC/SDIO/SPI peripheral and a working driver**, direct wiring to the card may make the FPGA bridge unnecessary. For a SoC without such a controller, expose the same read/write sector service over its chosen bus (UART, SPI slave, AXI/Wishbone, etc.). A basic SPI shift engine is not the complete card controller: SD initialization, CMD17/CMD24, response processing, CRC, block buffering and timeouts must be implemented in hardware or software.

## Proposed host API (binary framed protocol, not yet implemented)

Define a versioned framing layer with a fixed magic, version, opcode, sequence ID, payload length, 32-bit LBA in little-endian, payload and CRC32 over header+payload. The receiver must reject unsupported versions/opcodes, malformed lengths, bad CRC, unexpected sequence IDs and invalid LBAs. UART framing must resynchronise after lost or corrupted bytes and enforce bounded timeouts.

- `HELLO`, `GET_CAPABILITIES`, `CARD_STATUS` — discovery, card type, capacity, block size, read-only flag.
- `READ_SECTOR(lba)` → `status + exactly 512 bytes + frame CRC32` (v1 candidate).
- `WRITE_SECTOR(lba, payload[512])` → `status` **v2 only, disabled by default**.
- `READ_BACK_COMPARE(lba, 512 bytes)` / `VERIFY` — optional write verification.
- Diagnostic `GET_ERROR` — timeouts, R1 errors, token errors, CRC, card busy, bounds, prohibited writes.

Use two 512-byte buffers or adequate arbitration to prevent overwriting a sector while UART transmission or write staging is in progress. The UART/SD bridge must not assume that `peek_data` is combinational: the existing BSRAM reader has a synchronous read port. The host protocol should implement flow control and an explicit request/response completion handshake rather than relying on arbitrary timing.

## Safe read/write rollout

| Gate | Capability | Required evidence |
|---|---|---|
| HOST-00 | UART RX pin 18 loopback and `HELLO` | local SIM, Gowin STA, physical UART echo |
| HOST-01 | Python reads *arbitrary* sectors via FPGA | CMD17/BSRAM → framed 512B UART → host CRC32 + independent PC sector compare; read-only |
| HOST-02 | Python reads partition/BPB, directories and files through sector API | Python FAT32 access tested against a known image; no card writes |
| HOST-03 | `CMD24` one-sector write engine **on test media only** | explicit write-enable state, address validation, timeout/busy response, data response token, CRC where required, read-back verification, error injection |
| HOST-04 | Python FAT32 write operations via sector service | only after safe raw writes; exclusive media ownership, filesystem integrity tests, power-interruption cases |

**Do not silently introduce writes** to existing `cores/sdhc-spi-readonly/v1/` or to SD-01, SD-02, SD-03, SD-04, PiKoSoL. A separate versioned `sdhc-spi-rw/v2/` must implement new write behaviour and receive an independent acceptance receipt. By default `CAP_WRITE=0`. Writing may be enabled only on a spare/backup SD card with a deliberate, user-controlled enable; never infer that a sector not shown by the FAT32 decoder is safe to overwrite.

The host and any FPGA-autonomous FAT32 operations must have **one exclusive owner**. Do not let the PC mount the same volume through another card reader or a hypothetical USB MSC export while raw writes are issued via FPGA. Editing FAT32 safely requires updating FAT copies, allocation state, directory records and FSInfo as applicable; raw CMD24 support alone is **not** equivalent to filesystem-safe writes. A write-in-progress must not be falsely reported as successful until card-busy handling and verification complete.

At 115200 baud 8N1 the ideal UART payload ceiling is around **11.5 kB/s** before framing and command overhead. Read performance will be limited by the slower of UART framing, SPI, and SD transaction latency; benchmark before raising SPI clocks or proposing USB MSC.

## Grounded observations and nonclaims

- SD-03.4 read LBA0/VBR and decoded FAT32 metadata on Tang Nano 9K (operator-confirmed).
- SD-04.2 read the first root directory sector at LBA **17472**; decoded short alias `SYSTEM~1`, two LFN fragments and a directory entry with first cluster 3 (operator-confirmed).
- Current RTL has **no `uart_rx` port** and no arbitrary-sector UART dump or SD CMD24 path.
- **Nothing in this plan** gives current Python software access to SD sector contents via FPGA, writes a card, or converts existing USB/JTAG to a generic mass-storage endpoint.
- Next educational stage SD-04.3 may continue LFN decoding independently of this planned host bridge.
