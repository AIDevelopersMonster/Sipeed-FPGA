# SD-03 — MBR / FAT32 structural recognition on FPGA

**Status: initial RTL parsing experiment, simulation pending; not hardware verified.**

This **read-only** educational stage follows the [hardware-verified SD-02](../sd-multilba/). The intent is to identify a usable FAT32 partition and subsequently verify its BPB and layout, not merely search for the sector marker `55 AA`.

## SD-03.1: MBR partition selector

Input: streamed bytes from LBA0, `byte_valid` and `byte_index` (0–511); output: FAT32 partition LBA, declared length, partition type and entry index. Candidate partition types `0B` and `0C`; valid boot flags `00` or `80`; reject empty entries and invalid sector signature. A protective GPT type `EE` in entry 0 has a dedicated unsupported status.

```powershell
& .\boards\tang-nano-9k\experiments\sd-mbr-fat32\test.ps1
```

**Important:** This module only selects a partition-table *candidate*. It does not establish FAT32, nor does it have a complete end-to-end SD-02 connection yet. Its port data is a test stream; the SD-02 BSRAM-to-parser reader bridge is the next work package.

Next: SD-03.2 reads candidate partition boot sector via CMD17 and validates FAT32 BPB: `BytsPerSec=512`, `SecPerClus` power of two, nonzero `RsvdSecCnt`, `NumFATs`, `FATSz32`, `RootClus>=2`, total sectors and cluster-count bounds. Offsets and arithmetic use guarded 64-bit intermediates to avoid 32-bit overflow. Also support superfloppy only after BPB verification. GPT/exFAT require explicit separate handling rather than false classification.

[SD and microSD book](https://doi.org/10.5281/zenodo.23608853) · [SPI on FPGA book](https://doi.org/10.5281/zenodo.23608792) · [SD-02 hardware video](https://youtu.be/KdMJc_Ly7fQ).

This lab is intentionally independent of PiKoSoL v0.2.0, and never writes SD or configuration Flash.
