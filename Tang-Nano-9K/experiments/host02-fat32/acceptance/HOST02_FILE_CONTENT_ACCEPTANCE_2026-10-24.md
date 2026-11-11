# HOST-02 — read-only physical FAT32 file content acceptance

**Date:** 2026-10-24.
**Outcome:** `HOST02_FILE_CONTENT_PASS` for a single real 76-byte FAT32 file, supported by the operator-provided local file HEX dump and preceding FPGA-backed directory-listing evidence. This is the final educational functional gate for HOST-02.

## Evidence chain

1. Existing HOST-01 FPGA SRAM image, SHA-256 `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`: SDHC CMD17 sector transfers through UART, CRC-checked, 3/3 independently requested LBAs confirmed.
2. HOST-02 Python parser regression: 10/10 tests PASS.
3. `HOST02_FAT32_INFO_PASS PART=1 TYPE=0x0B START=64`, `SECTOR=512`, cluster=64 sectors, `DATA_LBA=17472`.
4. Root listing: `System Volume Information` at cluster 3.
5. Nested listing: `FILE CL=00000004 SIZE=76 NAME=IndexerVolumeGuid`; `HOST02_LIST_PASS ... ENTRIES=1 SECTOR_READS=4`.
6. Operator supplied output of `Format-Hex -Path .\indexer_volume_guid.bin`, showing **76 bytes** of local extracted file data, little-endian UTF-16 code units. The bytes decode to a brace-delimited **GUID** with 8-4-4-4-12 hexadecimal digits, 38 printable characters × 2 = 76 bytes. File contents semantically match a Windows `System Volume Information/IndexerVolumeGuid` file. The actual GUID is intentionally **not** reproduced in this public repository.

## Operator-provided HEX evidence (excerpt, redacted)

```text
PS C:\GitHub\Sipeed-FPGA-LAB05> Format-Hex -Path .\indexer_volume_guid.bin
Label: C:\GitHub\Sipeed-FPGA-LAB05\indexer_volume_guid.bin
Offset 0x00: 7B 00 ...        # '{' in UTF-16LE, followed by GUID digits
Offset 0x40: ... 7D 00        # '}' in UTF-16LE
5 rows: four 16-byte rows and one 12-byte row = 76 bytes.
```

This excerpt is not a copy of the entire local dump, which remains in the chat/operator's local records. No independent disk-image equality comparison has been performed. The **extraction CLI's final `HOST02_EXTRACT_PASS` line was not included** in the supplied transcript, so we do not claim to possess that exact console receipt. The local file HEX dump and its meaningful 76-byte UTF-16LE payload nevertheless provide direct evidence of file data being present on the PC after the earlier read-only extraction procedure.

## Accepted and unaccepted claims

**Accepted for this defined lab:** MBR/VBR parsing, FAT32 root/subdirectory traversal, VFAT long name resolution, locating a real file at cluster 4 and receiving/inspecting a 76-byte file payload, all with the pre-existing read-only FPGA sector interface. The software parser and 512-byte transport are modular, and no HDL change was required.

**Not accepted:** bulk file extraction, arbitrary exFAT/GPT support, multi-megabyte performance, damage recovery, independent card-reader byte equality, media write, general-purpose filesystem driver validation, or long-duration stress. No need to extend the acceptance test solely to exercise these non-goals.

**Decision:** Close HOST-02's small educational proof-of-concept at this point. The PR stays open for normal review/merge workflow; preserving the validated HOST-01 FPGA bitstream and not modifying the SD card.
