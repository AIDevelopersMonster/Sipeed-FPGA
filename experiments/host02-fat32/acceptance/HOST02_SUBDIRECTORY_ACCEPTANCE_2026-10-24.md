# HOST-02 — physical subdirectory traversal receipt

**Date:** 2026-10-24. **Status:** `HOST02_SUBDIRECTORY_PASS`; file content extraction remains pending.

**Evidence basis:** operator-provided Windows PowerShell output from the already hardware-qualified Tang Nano 9K running the unchanged HOST-01 read-only UART/FIFO/SDHC bitstream.

```text
PS C:\GitHub\Sipeed-FPGA-LAB05> python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 ls '/System Volume Information'
FILE CL=00000004 SIZE=        76 NAME=IndexerVolumeGuid
HOST02_LIST_PASS PATH=/System Volume Information ENTRIES=1 SECTOR_READS=4
PS C:\GitHub\Sipeed-FPGA-LAB05>
```

## Interpretation

- Root directory: cluster 2, starting at data LBA 17472 (previous INFO/ROOT receipts).
- `System Volume Information`: subdirectory, cluster 3, starting at LBA `17472 + (3-2)*64 = 17536`.
- `IndexerVolumeGuid`: **regular file**, size 76 bytes, first cluster 4, starting at LBA `17472 + (4-2)*64 = 17600`.
- The 4-sector read count is reported by the CLI; it includes MBR, VBR, root and subdirectory sector operations. It does **not** show a read of the content at LBA 17600.
- This is an actual physical FAT32 nested-directory listing over Python → FPGA → SDHC SPI `CMD17`, not an HDL simulation.
- Underlying bitstream and firmware were unchanged from HOST-01, SHA-256 `5BE3A5C02C54D69BC8ECCD9896C9571891DBD87A121E21CF4C112564FE7C4DE4`.

## Next bounded physical test (not yet reported)

```powershell
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 extract '/System Volume Information/IndexerVolumeGuid' --output 'indexer_volume_guid.bin' --max-bytes 128
Get-Item .\indexer_volume_guid.bin | Select-Object Name,Length
Format-Hex -Path .\indexer_volume_guid.bin
```

The CLI creates a local PC-side output file only, refuses to overwrite, and never issues any SD write command. Expect `HOST02_EXTRACT_PASS BYTES=76` if successful.

**Not yet accepted:** physical file data contents, file comparison with an independent card reader, sustained or general-purpose FAT32 stress, media writes, or a completed file-content hardware acceptance certificate.
