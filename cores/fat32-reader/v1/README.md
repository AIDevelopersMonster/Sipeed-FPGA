# Independent FAT32 read-only parser, v1

\`python/fat32_reader.py\` is independent of FPGA, UART, SPI, and HOST-01.
Its sole hardware dependency is the function \`read_sector(lba) -> bytes[512]\`.

- MBR primary FAT32 partition selection (types 0B/0C/1B/1C), FAT32-only 512-byte BPB validation and strict bounds.
- FAT32 28-bit cluster references, active FAT selection, cluster loops/errors and chains.
- VFAT LFN sequence plus 8.3 checksum verification, fallback to short names.
- Directory traversal, file reads through fragmented cluster chains and an LRU sector cache.
- Fail-closed default safety bounds: 256 unique sector reads, 128 clusters/chain, 2048 directory entries, 64 KiB/file.
- No device write API. A separate Python CLI may save extracted bytes to a **local PC file** only with an explicit output path.

Mock tests: \`python -m unittest discover -s cores/fat32-reader/v1/tests -v\`.

The parser is educational and does **not** support exFAT, GPT, FAT12/16, write operations, multi-partition selection, damage recovery or arbitrary corrupt-media tolerance.
