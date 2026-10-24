# SD-03 — MBR / FAT32 structural recognition on FPGA

**Status (24 October 2026): MBR, BPB and integrated two-stage scanner SIM PASS; NOT hardware verified.**

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

## SD-03.2 — BPB validator (simulation)

A second independent Verilog module, `rtl/sd03_fat32_bpb.v`, verifies a 512-byte VBR/BPB byte stream, rejects mismatched sector sizes, invalid cluster geometry, oversized volumes, undersized FATs, invalid signatures and exFAT. It computes first FAT/data/root cluster LBAs using wide arithmetic. The testbench includes a superfloppy VBR at LBA0; **this is not yet automatic MBR-vs-superfloppy detection**. Neither module is wired to SD-02 hardware in this revision.

The CI gate now runs MBR and BPB self-checking testbenches. A complete SD-03 physical acceptance requires a BSRAM streaming bridge, a scheduler for the follow-up CMD17 and real-board results. Documented outputs are design candidates, not automatically certified filesystems.

## SD-03.3 — two-stage BSRAM scanner (RTL candidate)

`sd03_volume_scanner.v` is the first *control-logic connection* to the SD-02 sector-reader interface: `sd_start`, `sd_lba`, `sd_done`, `sd_error`, 512-byte synchronous `peek_addr/peek_data`. It streams LBA0 through the MBR and BPB validators. If a FAT32 MBR candidate is found, the scanner requests its boot-sector LBA via a second CMD17 and validates BPB. If no candidate MBR exists, it accepts a standalone FAT32 BPB in LBA0 as a superfloppy. Protective GPT returns an explicit unsupported status.

The scanner now has an **integrated behavioral simulation PASS** against a synchronous sector-memory model, including two-sector MBR→BPB selection, superfloppy, GPT and invalid BPB. This is **not a real SDHC SPI card test**: a physical Tang Nano 9K UART top, local Gowin PnR/STA and board acceptance are still required. There is no FAT entry lookup, directory traversal, file opening or writing.

Pass order: MBR RTL PASS, BPB RTL PASS, scanner compile PASS, integrated behavioral test PASS ([CI evidence](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40068297667)); Gowin PnR/STA PENDING, board UART PENDING.
