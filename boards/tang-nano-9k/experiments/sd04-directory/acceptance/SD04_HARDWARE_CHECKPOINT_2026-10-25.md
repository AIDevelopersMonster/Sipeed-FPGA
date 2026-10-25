# SD-04 — physical checkpoint (25 October 2026)

**Result: operator-confirmed SRAM programming, real FAT32 ROOT content, and strict FULL 512-byte UART frame PASS. Independent host-sector comparison remains pending.**

## Exact build

- Bitstream: `sd04_root_dump_nano9k.fs`, local build run
  `run_20261024_233128_167_640229`
- SHA-256 as reported by build:
  `9A47ECEFC0116723AA7D704AECD973526C313588A0CA69A1AFEB6B81E3DCBD59`
- Internal STA at 27 MHz: **0 setup and 0 hold violated endpoints**;
  worst setup slack +17.680 ns, worst hold slack +0.708 ns,
  setup/hold TNS 0.000 ns; internal Fmax 51.660 MHz.
- Logic 2099/8640 (25%), FF 1546/6480 (24%), BSRAM 4%.
- External SD MISO return timing not independently characterized.

## Operator evidence

1. SRAM programming command printed
   `LAB04_SRAM_PROGRAM_COMMAND_PASS: programmer reported exit 0`.
   The programmer status does not independently verify bitstream SHA at
   the time of writing; use the canonical source build receipt.
2. First UART HEX paste started partway through a long-name entry; it
   was not a fully framed capture.
3. After pressing physical reset, the next UART paste began
   `42200049006E0066006F000F0072...`; it contained two FAT32 long-name
   entries with sequence markers `0x42`, `0x01`, and a matching 8.3
   directory entry `SYSTEM~1` with `ATTR=0x16`, cluster 3.
4. These bytes are consistent with the standard Windows-created
   `System Volume Information` directory. The recognized content is
   credible physical evidence for the ROOT-sector CMD17 path.

## Distinct acceptance levels

| Gate | Status |
|---|---|
| Python + RTL stub regression | PASS reported by operator |
| Gowin build and internal STA | PASS, operator report |
| SRAM programming | PASS, programmer exit 0 |
| Actual ROOT-sector content | Plausible directory entry seen |
| Exact 1024-character UART frame | **PASS**, pyserial controlled capture COM10 |
| SHA-256 of complete ROOT sector | **PASS** computed from captured 512 bytes |
| Bytewise comparison with PC block device | PENDING |
| Arbitrary-LBA command/reply | NOT IMPLEMENTED |
| Writing CMD24 / Python file creation | NOT IMPLEMENTED |

The read-only UART capture utility is
`tools/sd04_capture.py`, to be run before board reset; it refuses
truncated, non-HEX, extra or malformed frames. Capture outputs stay in the
ignored local `build/` directory.

**No new bitstream**, RTL logic changes, SD-card write, or integration into
PiKoSoL is implied by this checkpoint. Freeze the current known-good SD-04
physical candidate while preserving the already satisfied UART capture gate.


## Controlled UART full-frame acceptance — operator terminal log

- Date: **25 October 2026**, local capture name `capture_20261025_054947`.
- Port **COM10**, 115200 8N1. Operator opened `sd04_capture.py`
  before pressing board S2 reset.
- Strict parser returned `SD04_FRAME_PASS: 1024 HEX characters, 512 bytes, CRLF`.
- Hash of **captured sector bytes**, not the bitstream:
  `A545DFF293AE619D471BB8E97311DF4004D2FF01AF0DFA2EA2205469E45BEF7F`.
- Capture files (local ignored artifacts, **not** uploaded to GitHub):
  `build/capture_20261025_054947/root.hex` and `root.bin`.
- Decoded entry:
  `SD04_ENTRY: 02 SYSTEM~1 ATTR=16 CLUS=00000003 SIZE=0`.

```text
SD04_PORT_OPEN: COM10 115200 8N1
NOW PRESS BOARD S2 RESET while this command is running.
SD04_FRAME_PASS: 1024 HEX characters, 512 bytes, CRLF
SD04_SECTOR_SHA256: A545DFF293AE619D471BB8E97311DF4004D2FF01AF0DFA2EA2205469E45BEF7F
SD04_ENTRY: 02 SYSTEM~1 ATTR=16 CLUS=00000003 SIZE=0
SD04_NOTE: UART frame has no LBA/CRC metadata; host comparison remains pending
```

**Final scope:** SD-04 **hardware UART ROOT-sector read PASS** for one
microSD card on one Tang Nano 9K and the specified bitstream. No data or
firmware changes were made to SD-01/02/03 or PiKoSoL.
Independent host physical LBA comparison, externally constrained SD MISO timing,
multi-card compatibility and autonomous FAT chain traversal are **not**
proved. Preserve the current qualified bitstream unchanged. Development of
arbitrary-LBA control begins in an isolated SD-05 experiment.
