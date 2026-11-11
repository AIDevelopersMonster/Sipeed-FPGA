# HOST-02 FAT32 Reader — hardware information and root directory acceptance

**Date:** 2026-10-24  
**Status:** `HOST02_INFO_ROOT_PASS` (two read-only physical checks); full file-content read has **not** been demonstrated.
**Evidence source:** Operator's PowerShell output from Tang Nano 9K using the existing HOST-01 UART / SDHC CMD17 read-only FPGA configuration.

## Operator-provided transcript

```text
Ran 10 tests in 0.007s

OK
PS C:\GitHub\Sipeed-FPGA-LAB05> python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 info
HOST02_FAT32_INFO_PASS PART=1 TYPE=0x0B START=64
SECTOR=512 CLUSTER_SECTORS=64 CLUSTER_BYTES=32768
FAT0_LBA=2112 DATA_LBA=17472 ROOT_CLUSTER=2 ROOT_LBA=17472
CLUSTERS=983007 SECTOR_READS=2
PS C:\GitHub\Sipeed-FPGA-LAB05> python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 ls /
DIR  CL=00000003 SIZE=         0 NAME=System Volume Information
HOST02_LIST_PASS PATH=/ ENTRIES=1 SECTOR_READS=3
PS C:\GitHub\Sipeed-FPGA-LAB05>
```

## Verified scope

- Ten synthetic parser tests passed locally.
- Hardware reads through Python → UART/FIFO → SDHC returned consistent MBR FAT32 partition type 0x0B and LBA start 64.
- BPB: 512-byte logical sector, 64 sectors/cluster (= 32768 bytes), FAT0 LBA 2112, data region LBA 17472, root cluster 2 and root LBA 17472.
- Computed FAT32 cluster count: 983007.
- Root listing found exactly one entry, directory `System Volume Information`, first cluster 3, size field zero (normal for FAT32 directory entries). Long filename resolved via parser's VFAT LFN support.
- INFO required 2 distinct sector reads and ROOT listing 3 in the user's output.

## Acceptance boundary

No normal root-level files were found. The system directory itself has **not** yet been listed, and no file contents have been read by HOST-02. No SDHC/RTL modifications, flash writes, FAT modifications, or media repairs have been made. The operator's test does not establish unlimited arbitrary-file support or stress-test resilience.

Next single bounded, read-only command:

```powershell
python .\experiments\host02-fat32\tools\host02_fat32.py --port COM10 ls '/System Volume Information'
```

If the directory contains no suitable small regular file, record that fact and stop or use an explicitly prepared separate test card for the later file-content test. Do not assume that a test file already exists.
