# SD-05.2 — physical multi-cluster FAT32 file read, 25 October 2026

**FINAL VERDICT: HARDWARE MULTI-CLUSTER READ PASS on the second SDHC/FAT32 microSD. FAT chain is PHYSICALLY CONTIGUOUS (6,7,8,9,10; zero discontinuities), NOT a fragmented-chain hardware test. Verified through the unchanged Tang Nano 9K SD-05 read-only bitstream.**

## Operator sequence

- SRAM Gowin programmer: `Programming... 100%`, user code `0x00008F7E`, status `0x0003F020`, exit 0 reported by `LAB04_SRAM_PROGRAM_COMMAND_PASS`. No configuration Flash change intended.
- The bitstream was the established SD-05 candidate, whose recorded SHA-256 is `BCA9FEF2F9786DDDB44286983CAE176921DEA66EF4E8FB791C677685FB373855`. The programmer output in this turn did **not** independently include a SHA-256 recheck; do not fabricate one.
- Python control `COM10`, 115200 8N1; read-only SDHC CMD17. The card was distinct from the original SD-05 test card, with a different FAT32 layout.
- The test file `SD052.BIN` was placed on the separate prepared microSD using the PC. FPGA readback itself never issued any SD write commands.

## Exact card geometry reported by host FAT32 parser

| Field | Value |
|---|---:|
| Partition start LBA | 8192 |
| First FAT absolute LBA | 8224 |
| DATA/ROOT initial absolute LBA | 10142 |
| Sectors per cluster | 64 |
| Bytes per cluster | 32768 |
| Data cluster count | 122721 |
| Test file starting cluster | 6 |

```text
SD051_VOLUME_PASS: VOL=8192 FAT=8224 DATA=10142 ROOT=10142 SPC=64 CLUS=122721
DIR           0 CLUS=00000003 ATTR=16 System Volume Information
FILE     131073 CLUS=00000006 ATTR=20 SD052.BIN
SD051_LS_PASS: PATH='/' ENTRIES=2 SECTORS_READ=3
```

## Complete operator file readback

```text
SD051_VOLUME_PASS: VOL=8192 FAT=8224 DATA=10142 ROOT=10142 SPC=64 CLUS=122721
SD051_FILE_PASS: BYTES=131073 SHA256=3C7B9082211B55C9FA5697A673EECE6E9B1802C0E1BA4AAB101FDE73FA673846 SECTORS_READ=264
SD051_PC_FILE: SD052_READBACK.BIN
(Get-Item '.\SD052_READBACK.BIN').Length
131073
(Get-FileHash '.\SD052_READBACK.BIN' -Algorithm SHA256).Hash
3C7B9082211B55C9FA5697A673EECE6E9B1802C0E1BA4AAB101FDE73FA673846
```

The 131073-byte file occupies **5 FAT32 clusters** of 32 KiB; four complete clusters plus **1 byte** of useful data in the final cluster. The host reported **264 unique sectors read** including FAT and directory metadata. File SHA-256 exactly matches the pre-existing independently generated source-file expectation, and a separate PowerShell `Get-FileHash` repeated the identical digest. Therefore the hardware block reads plus Python filesystem logic reconstructed a real five-cluster file with byte-level integrity.

## Claims and limits

- **Accepted:** multi-sector and multi-cluster real-file read on a **second** SDHC card with a different partition/FAT32 geometry, 512-byte UART frame transport and SHA-256 end-to-end match. No changes to FPGA RTL or the accepted bitstream were required.
- **Not yet proved:** whether the five file clusters are contiguous or physically fragmented. The starting cluster is 6; the remaining four cluster numbers were not in the operator log. A read-only FAT chain audit can determine this without another full file read.
- **Not claimed:** sector-write support (CMD24), FAT updates, configuration-Flash programming, power-loss recovery, multi-card stress, or guaranteed SD MISO external timing closure. The two observed card configurations establish functional portability for those samples only.
- **Preservation:** original SD-01/02/03, SD-04, SD-05 and PiKoSoL artifacts remain unchanged.

**Next optional gate:** read only FAT entries for `/SD052.BIN` and print the five cluster numbers; if every successor equals its predecessor + 1, this test was contiguous, not a fragmented-chain hardware PASS. No modifications to the test card are necessary.


## Final read-only FAT chain check — operator terminal transcript

```text
python .\boards\tang-nano-9k\experiments\sd05-lba-bridge\tools\fat_chain_audit.py --port COM10 --path /SD052.BIN
SD052_CHAIN: FILE='/SD052.BIN' SIZE=131073 SPC=64 CLUSTERS=5 DISCONTINUITIES=0
SD052_CLUSTER_SEQUENCE: 6,7,8,9,10
SD052_CHAIN_PASS
```

**Interpretation:** the complete FAT sequence was read through the tested FPGA and has four consecutive links, hence no fragmentation. The 131073-byte file crossed five 32768-byte clusters and was copied back with exact expected SHA-256 `3C7B9082211B55C9FA5697A673EECE6E9B1802C0E1BA4AAB101FDE73FA673846`.

**Completed scope:** SD-05.2 contiguous multi-cluster file read hardware PASS. Fragmented FAT traversal PASS only in synthetic offline tests (13/13), **not on physical media**. No need to alter the accepted card or bitstream to complete this stage. Next work is a new isolated SD-06 development branch; CMD24 remains disabled until explicit disposable-card authorization.
