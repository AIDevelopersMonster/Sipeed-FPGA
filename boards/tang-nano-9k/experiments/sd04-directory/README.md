# SD-04 — FAT32 directory read-only RTL (first module)
**Status: isolated parser under behavioral verification, no SD-04 FPGA hardware pass.**

This lab extends the SD-03 hardware-confirmed MBR/FAT32 layout discovery. Its first module accepts the 512-byte **first root-directory sector** as an indexed byte stream and classifies 32-byte directory records: short 8.3 file, directory, LFN entry, deleted entry, volume label, end marker. It extracts 11-byte raw name, attribute byte, first-cluster number and file size. It does **not** reconstruct LFN names or follow FAT chains.

On the specific SD-03 card the FPGA calculated LBA **17472** for the first root-directory sector, but that sector has **not yet been read in hardware**. The testbench uses synthetic sector data, not the physical SD card. No write commands.

**Shared read-only core source**: `../../cores/sdhc-spi-readonly/v1/rtl/`, copied without modification from SD-02, with SHA provenance documented in its README. This is a new canonical source for future builds, **not** a retroactive replacement of frozen SD-02/03 code.

Next: connect SD-04 parser to SDHC RAM and the SD-03 layout values, test full read+UART integration, then synthesize (Gowin PnR/STA) and accept real hardware; LFN reconstruction, FAT-chain navigation and contents are separate gates.

[SD-03 hardware receipt](../sd-mbr-fat32/acceptance/SD03_HARDWARE_ACCEPTANCE_2026-10-24.md) · [SD-03 demonstration video](https://youtu.be/BhSR5UGi3A8).
