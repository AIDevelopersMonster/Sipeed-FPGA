# SD-04.2 — Read-only FAT32 first root directory sector on Tang Nano 9K

**Status (2026-10-24): operator-confirmed HARDWARE FUNCTIONAL PASS for read-only FAT32 first root-sector decoding, following RTL SIM PASS, Gowin PnR and internal STA PASS.**

## Architecture: additive, not a controller rewrite

Reuse the immutable, byte-for-byte SD-02 core source from `../../cores/sdhc-spi-readonly/v1/rtl/`. This experiment links independent snapshots of the already verified SD-03 MBR/BPB RTL under `rtl/sd03_*.v` (the source of SD-03 itself is unchanged), plus three new SD-04 modules:

- `sd04_directory_parser.v`: raw 32-byte FAT32 directory entries; short 8.3 name, attribute, first cluster and size; file/directory/LFN/deleted/volume/end classification.
- `sd04_uart_report.v`: print fixed-width hexadecimal UART status and entries. Raw 8.3 name is shown as 8+dot+3 characters; spaces are not trimmed, and any non-printable raw byte is shown as a question mark.
- `sd04_directory_probe_top.v`: MBR→VBR scan, then read the **computed** root LBA via an additional CMD17 (no hardcoded production LBA), stream the 512-byte synchronous BSRAM buffer through the entry parser, and emit records via UART.

There is **no embedded CPU, no FAT updates, no SD writes, no configuration-Flash operations**. The card from SD-03 indicated **root LBA 17472**, and SD-04 has now **physically read and decoded its first root directory sector**.

The first root directory sector holds up to **16 directory entries of 32 bytes**. This implementation stops at the first unused entry `0x00` or after all sixteen entries. It does not yet follow directory cluster chains, open files or reconstruct long file names; LFN fragments are counted and skipped. It is deliberately limited to one root directory sector.

## Local regression (Windows PowerShell 7)

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git fetch origin
git switch --track origin/agent/sd04-fat32-directory
& .\boards\tang-nano-9k\experiments\sd04-directory\test.ps1
```

If the branch already exists locally, use `git switch agent/sd04-fat32-directory; git pull --ff-only` instead of `switch --track`.

`test.ps1` covers FAT32 entry classifications and a **mock** root-sector handshake with read-only CMD17 request and simulated UART. [Current GitHub Actions regression](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40083478370) passed. The mock is synthetic and is not proof of real SPI timing.

## Build (no hardware programming)

```powershell
& .\boards\tang-nano-9k\experiments\sd04-directory\build.ps1
```

The script snapshots all Verilog sources, core sources, constraints and the build script, computes per-file SHA-256, invokes Gowin and creates a unique `build/run_*/sd04_directory_nano9k.fs` candidate. Review `*_tr_content.html` and `*.rpt.txt`: setup violated endpoints = **0**, hold violated endpoints = **0**, and TNS = 0 before discussing SRAM programming. Do **not** program any candidate that misses these timing gates. External SD MISO input timing is not fully characterized.

The physical interface is unchanged from SD-03: Tang Nano 9K, clock 27 MHz, SD SPI approximately 211 kHz, SD SCK pin 36, MOSI 37, CS 38, MISO 39, UART TX pin 17, reset S2 pin 3; UART **115200 8N1**.

## Actual SD-04.2 UART hardware receipt

[Complete physical hardware acceptance](acceptance/SD04_HARDWARE_ACCEPTANCE_2026-10-24.md) · [verbatim terminal output](acceptance/SD04_UART_2026-10-24.txt)

```text
SD04 ROOT=00004440 VOL=00000040 FAT=00000840 E=00
SD04 IDX=02 K=D NAME=SYSTEM~1.    A=16 CL=00000003 SZ=00000000
SD04 END FILE=00 DIR=01 LFN=02 SKIP=00 STOP=01
```

The actual card's first root-directory sector contains two LFN fragments and one hidden/system directory (`SYSTEM~1`, cluster 3), then an end marker. The complete Unicode long name is *not* reconstructed, and no file data or subdirectory clusters were read. `E=00` indicates no SD-controller-reported read error. The first line of the operator's combined log is a prior SD-03 report, not SD-04 output.

## Synthetic UART record types (examples from testbench, not physical capture)

```text
SD04 ROOT=00004440 VOL=00000040 FAT=00000840 E=00
SD04 IDX=00 K=F NAME=README  .TXT A=20 CL=00000005 SZ=000004D2
SD04 IDX=01 K=D NAME=DIR     .    A=10 CL=00000000 SZ=00000000
SD04 END FILE=01 DIR=01 LFN=01 SKIP=01 STOP=01
```

The testbench uses **synthetic directory entries**. The real card's file names and actual root directory contents are *not known*. Under the current protocol `K=F` is file, `K=D` directory, `STOP=01` first 0x00 terminator, `STOP=02` end of sixteen entries. A failure in initial MBR/BPB scan produces `SD04 SCAN_ERR=...`, whereas a later root-sector CMD17 failure produces `SD04 ROOT_ERR=...`. Do not mistake unsupported FAT32 format for a card transport failure.

## Evidence boundary and next hardware acceptance

**First gate:** run local regression, then Gowin PnR/STA and hash verification. **Second gate:** explicitly program only *volatile SRAM* using the independently verified prior LAB-04 Gowin programmer helper, not configuration Flash. **Third gate:** capture the complete UART line(s) from the actual microSD. Preserve the log verbatim for hardware acceptance.

[SD-03 UART hardware receipt](../sd-mbr-fat32/acceptance/SD03_HARDWARE_ACCEPTANCE_2026-10-24.md) · [SD-03 video](https://youtu.be/BhSR5UGi3A8) · [shared SDHC core](../../cores/sdhc-spi-readonly/v1/README.md).

## Engineering status after hardware acceptance

The SHA-verified bitstream `4757572F373B807862BC02F117EC4B33C4B8CE491DE3218D098F3809E0B1A9BA` passed internal STA (0 setup/hold violations, both TNS=0, worst shown setup slack +15.329 ns). New RTL changes require a new STA gate. No change was made to SD-02, SD-03, PiKoSoL or the frozen shared SDHC core. The next work package is LFN decoding and then read-only cluster traversal.

## Interactive offline HTML atlas — SD-04.2

[**Open / download the FAT32 directory interactive demo**](demo/index.html) ([Raw HTML](https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/agent/sd04-fat32-directory/boards/tang-nano-9k/experiments/sd04-directory/demo/index.html)). Save the HTML file and open locally in Chrome/Edge; no external libraries or internet connectivity after download.

The page explains the hardware path **LBA 0 (MBR) → LBA 64 (BPB/VBR) → LBA 17472 (read-only root directory)**; distinguishes **LBA 2112 (FAT address computed, but not read)**. The physical UART `SYSTEM~1`, `ATTR=16`, `CL=3`, `LFN=2` are clearly marked as the real result. Because SD-04 only transmitted decoded fields, original raw 512-byte bytes are **unknown** in the hardware mode.

The demo has a synthetic, explicitly labelled 512-byte sector with a valid 8.3 directory and LFN fragments, an interactive HEX view and local file upload of either a real 512-byte sector or an entire SD-card image. For an image the browser uses slice reads for LBA0, FAT32 VBR and first root-directory sector. Long-name decoding includes LFN order and SFN checksum validation. **Browser file parsing is not FPGA hardware functionality** and does not write to the user card.

## Reserved PC Python / SoC bridge (future, NOT implemented)

The design also reserves a future **host-controlled sector service**: `Python/PC ↔ USB-UART (BL702, FPGA TX pin 17 / RX pin 18) ↔ FPGA read/write block API ↔ SDHC SPI`. An autonomous FAT32 teaching FSM and a Python filesystem client should both use the **same** arbiter-controlled SDHC core. The current firmware remains **TX-only and read-only**: the ability to *display* UART directory summaries is not equivalent to reading or writing arbitrary sectors from Python. Host read-only CMD17 comes first; write-capable CMD24 requires a separate versioned core, test media, CRC/timeouts and read-back verification. [Architecture, protocol and rollout gates](HOST_SD_PYTHON_SOC_ARCHITECTURE.md).
