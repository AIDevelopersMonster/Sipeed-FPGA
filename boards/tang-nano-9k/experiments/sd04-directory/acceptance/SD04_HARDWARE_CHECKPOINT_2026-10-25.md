# SD-04 — physical checkpoint (25 October 2026)

**Result: operator-confirmed SRAM programming and plausible real FAT32 ROOT
directory read over UART. Full 512-byte frame and independent host-sector
comparison still pending.**

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
| Exact 1024-character UART frame | PENDING controlled COM capture |
| SHA-256 of complete ROOT sector | PENDING |
| Bytewise comparison with PC block device | PENDING |
| Arbitrary-LBA command/reply | NOT IMPLEMENTED |
| Writing CMD24 / Python file creation | NOT IMPLEMENTED |

The read-only UART capture utility is
`tools/sd04_capture.py`, to be run before board reset; it refuses
truncated, non-HEX, extra or malformed frames. Capture outputs stay in the
ignored local `build/` directory.

**No new bitstream**, RTL logic changes, SD-card write, or integration into
PiKoSoL is implied by this checkpoint. Freeze the current known-good SD-04
physical candidate until the capture gate is satisfied.
