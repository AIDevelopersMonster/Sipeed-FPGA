# HOST-02 — FAT32 Reader via existing HOST-01 FPGA firmware

**Stage 1 hardware acceptance: FAT32 INFO PASS and ROOT LIST PASS (2026-10-24); file reading still pending.** Existing HOST-01 bitstream is reused unchanged (SHA-256 `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`). **No FPGA rebuild, no SD writes.**

Architecture: Python `host02_fat32.py` → unchanged HOST-01 UART request/response client → existing FPGA UART / FIFO / SDHC CMD17 → raw 512-byte sectors → independent `cores/fat32-reader/v1/python/fat32_reader.py` FAT32 parser.

Only classic MBR FAT32 partition type 0B/0C/1B/1C is supported. GPT/exFAT/FAT12/16 are rejected.

## Commands from repository root

```powershell
git fetch origin
git switch --track origin/agent/host02-fat32-reader
python -m unittest discover -s cores/fat32-reader/v1/tests -v
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 info
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 ls /
```

**Only after `info` and `ls /` pass**, select a small, known file from the listing and optionally:

```powershell
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 cat '/FILE.TXT' --max-bytes 4096
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 extract '/FILE.TXT' --output 'readback.txt' --max-bytes 65536
```

The latter creates a **local PC file** only, refuses to overwrite an existing file, and never writes to SD. The input file path is an example, **not a claim that this file exists on the card**.

First acceptance gate: Python pure-software regression + `HOST02_FAT32_INFO_PASS` + `HOST02_LIST_PASS` from actual microSD. Full file content extraction will be a separate gate. If two or three simple physical tests fail, stop and record the limitation; do not repeatedly rewrite working FPGA cores.

## Actual board results: FAT32 information and root listing (2026-10-24)

[Read the evidence receipt](acceptance/HOST02_INFO_ROOT_ACCEPTANCE_2026-10-24.md). Local Python regression: `10 tests OK`; live FPGA/UART: `HOST02_FAT32_INFO_PASS`, `HOST02_LIST_PASS`. The partition starts at LBA 64 (MBR type 0x0B); the data region starts at LBA 17472; the root is cluster 2. Root has one entry: `System Volume Information`, directory, first cluster 3. No regular files are listed at the root. **This verifies directory listing, not yet reading file contents.**

Recommended next single read-only test:

```powershell
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 ls '/System Volume Information'
```

The parser's per-command sector-read safety limit is 256. Continue to regular-file content only if a small real file is found; do not invent file names or modify the card.

## Subdirectory hardware acceptance (2026-10-24)

[Read the subdirectory acceptance receipt](acceptance/HOST02_SUBDIRECTORY_ACCEPTANCE_2026-10-24.md). The real card contains `/System Volume Information/IndexerVolumeGuid`, a **76-byte ordinary file** whose first cluster is 4. `HOST02_LIST_PASS ... ENTRIES=1 SECTOR_READS=4` was observed on COM10. Nested-directory traversal is physically confirmed; **file data has not yet been extracted**. The next bounded test reads this file only, using `extract` with `--max-bytes 128` and a new PC-side output file. The accepted FPGA bitstream remains unchanged.
