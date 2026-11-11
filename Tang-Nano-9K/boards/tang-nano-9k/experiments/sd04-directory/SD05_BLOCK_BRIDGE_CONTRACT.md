# SD-05 proposed contract — Python-controlled read-only LBA bridge

**Architecture specification only. Not implemented, not simulated, not STA-verified, not programmed.**

## Objectives

Preserve SD-04 as the immutable hardware-proven read-only root-sector
experiment. In an **independent SD-05 directory**, reuse the verified SDHC
CMD17 SPI core and one 512-byte RAM sector buffer. Python is authoritative
for filesystem geometry, FAT32 traversal, file lookup and integrity checks.
No FAT32 parsing is needed in the SD-05 RTL.

## Pin/clock precondition

- 27 MHz single fabric clock, SD SPI at proven conservative rate.
- SD pins and UART TX from SD-03, unchanged.
- **Do not invent a UART RX pin**. Audit Tang Nano 9K schematic, UART
  connector and physical bank voltage; create and audit a separate RX CST.
- If USB/UART path is TX-only, add an external proven 3.3V RX connection
  or postpone host commands. No speculative pin reassignments.
- Reuse hardware-source SHA-256 manifest and STA gate; no implementation
  until electrical UART RX feasibility is verified.

## Proposed binary request/response v0 (read only)

- UART: 115200, 8N1; no concurrent terminal; one outstanding request.
- Request: `A5 52 seq[1] lba[4 little-endian] crc16[2]` (9 bytes).
- Response on success: `5A 44 seq[1] lba[4 LE] 00 00 payload[512]
  crc16[2]` (523 bytes).
- Response on failure: `5A 45 seq[1] lba[4 LE] err[1] crc16[2]`
  (10 bytes); no arbitrary sector payload on failure.
- CRC16/CCITT-FALSE, poly 0x1021, init 0xFFFF, no reflection,
  computed over every frame preceding its CRC field.
- Python validates magic, sequence, echoed LBA, payload size and CRC;
  rejects stale/partial/wrong-sector frames.
- FPGA accepts only command `R` (0x52); invalid commands must never
  trigger an SD write. No CMD24 and no host-driven raw SPI in SD-05.
- Replay rule: after timeout, Python resets the UART transaction state
  before retry; FPGA handles duplicate seq/LBA as new read-only requests.
- Prefer a 512-byte response buffer or a strictly flow-controlled UART
  serializer. At 115200 8N1 one full response takes approximately 45.4 ms,
  so an initial timeout >=2s leaves ample room for SD-card response.
- Target read-only CLI: `sdtool.py info`, `sdtool.py read --lba N --out f.bin`,
  `sdtool.py verify --lba N --against host.bin`.

**The frame above is an engineering proposal, not a published protocol
supported by the current SD-04 bitstream.** No code should attempt to
send it to SD-04; SD-04 only emits an automatic one-shot HEX dump.

## Test gates

1. Exact UART RX electrical route and 3.3V logic verified.
2. Byte serializer test and malformed length/CRC/seq/LBA/error tests,
   separate from SD controller.
3. Integrated SD-05 simulation with mock SDHC core + real core compile.
4. Gowin build, 0 setup/hold violations, source hashes, no externally
   unconstrained clock crossings, review GPIO timing.
5. SRAM-only read of LBA 0, LBA 64, LBA 17472; bytewise compare
   with read-only PC captures. Stop after 2–3 bounded physical tests
   if repeated failure; diagnose link/power/timing rather than rewrite RTL.
6. Freeze this independently useful reader before any CMD24 write experiment.

## Writing as later, separate SD-06

Python chooses file allocation and FAT updates, but writable filesystem
support must be transaction-safe. The minimal FPGA action will be sector
CMD24 write with response/busy/timeout handling followed by CMD17 verify.
Only a sacrificial, backed-up SD card may be used for any writable experiment.
