# SD-03 — MBR/FAT32 read-only discovery on Tang Nano 9K

**24 October 2026: HARDWARE FUNCTIONAL PASS — FAT32 volume geometry discovery from a real microSDHC, without CPU.** Not a FAT file reader.

[Hardware acceptance receipt](acceptance/SD03_HARDWARE_ACCEPTANCE_2026-10-24.md) · [Exact UART](acceptance/SD03_UART_2026-10-24.txt) · [Gowin build + STA history](acceptance/SD03_BUILD_2026-10-24.md) · [SD-02 prior hardware experiment](../sd-multilba/).

## Confirmed physical UART

```text
SD03 RESULT=MBR_FAT32    VOL=00000040 FAT=00000840 DATA=00004440 ROOT=00004440 CLUS=000EFFDF E=00
```

This independently constructed, read-only FPGA probe used LBA0 to locate an MBR FAT32 candidate at **LBA 64**, then checked its VBR/BPB and calculated first FAT LBA **2112**, data and root LBA **17472**, and **983007** clusters. No SDHC errors were reported (`E=00`). FAT32 directory entries, files and FAT cluster chains have **not** been read.

## Components

- `rtl/spi_byte.v`, `rtl/sd_read_sector.v`, `rtl/uart_tx_8n1.v`: independent SD-02-derived SPI/SDHC and UART RTL snapshot.
- `rtl/sd03_mbr_parser.v` (SD-03.1): MBR partition entries, FAT32 types 0B/0C, protective GPT EE.
- `rtl/sd03_fat32_bpb.v` (SD-03.2): FAT32 BPB field checks, sequential geometry arithmetic, 32-bit LBA boundaries and FAT capacity constraints.
- `rtl/sd03_volume_scanner.v` (SD-03.3): LBA0 parse, optional follow-up CMD17 on selected partition VBR, superfloppy fallback and unsupported-format classifications.
- `rtl/sd03_mbr_fat32_probe_top.v` (SD-03.4): synthesizable Tang Nano 9K hardware top with UART summary and active-low LED status.
- `tests/`: behavioral MBR, BPB and synchronous sector-buffer scanner tests.
- `constraints/`, `build.tcl`, `build.ps1`: independent Gowin build (no automatic hardware programming).

## Reproduce in Windows PowerShell 7

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git fetch origin
git switch agent/sd03-mbr-fat32-parser
git pull --ff-only
& .\boards\tang-nano-9k\experiments\sd-mbr-fat32\test.ps1
& .\boards\tang-nano-9k\experiments\sd-mbr-fat32\build.ps1
```

These commands are read-only toward the card and do not program FPGA. The accepted bitstream was `build/run_20261024_095913_693_c293c8/sd03_mbr_fat32_nano9k.fs` with SHA-256 `2F5221EA95F91EE27F4B5BD2E10B4738CAF592F2113EC807A0C68433EFBF51A2`. **Do not substitute** the earlier bitstream that failed 27 MHz STA (129 setup violations). The accepted build shows **0 setup and 0 hold timing violations**, both TNS values 0.000 ns, resources 32% logic / 31% FF / 4% BSRAM; full external SD MISO timing remains uncharacterized.

An explicit *SRAM-only* programmer, if needed on another physical test, is `01-PicoRV32/lab04/tools/program_lab04_sram.ps1` with `-Program`, `-Bitstream` and `-CableIndex 1` after checking the hash and local STA. Flash and SD writes are outside this experiment.

## UART classification

One record after reset at 115200 8N1. `MBR_FAT32` and `SUPERFLOPPY` indicate validated FAT32 BPB geometry; `GPT_UNSUP`, `NO_FAT32`, `INVALID_BPB`, `SD_READ_ERR` describe distinct outcomes. The observed result is `MBR_FAT32`. Unsupported format is **not** an SD transport failure.

## Limits and next phase

The observed UART came from the experiment operator; no independent PC sector dump or external SPI capture was supplied. It does not establish cluster chains, file contents, GPT/exFAT support, or PiKoSoL integration. Next research gate: verify volume geometry on a PC (read-only), then implement FAT32 directory and FAT-chain readers separately.

Educational manuscripts: [MBR and FAT32 concepts](../../../../docs/education/MBR_FAT32_Concepts_RU_v0.1.md) · [FAT32 on FPGA implementation](../../../../docs/education/FAT32_on_FPGA_RU_v0.1.md). These are research drafts, not released Zenodo editions.

## Interactive HTML teaching atlas

[Open the standalone interactive demo](demo/index.html) or download `demo/index.html` and open it locally in Chrome/Edge (no server, no external libraries). It illustrates the physical CMD17 reads at **LBA 0** (MBR) and **LBA 64** (VBR/BPB), then highlights the **calculated, not yet read**, first FAT LBA **2112** and DATA/ROOT LBA **17472**. The clickable fields use format-standard offsets and only values supported by the 24 October 2026 UART; unknown raw bytes and the original full 512-byte sector dumps are intentionally not fabricated. The LBA inspector does no card I/O. Source: [SD-03 hardware acceptance](acceptance/SD03_HARDWARE_ACCEPTANCE_2026-10-24.md).
