# SD-03.4 — Tang Nano 9K hardware acceptance, 24 October 2026

**VERDICT: operator-confirmed HARDWARE FUNCTIONAL PASS for read-only MBR/FAT32 layout discovery.** This is not a file-access or cross-device validation claim.

## Evidence provenance and identity

- Board: Sipeed Tang Nano 9K, Gowin GW1NR-9C, 27 MHz internal clock.
- Tested RTL top: `sd03_mbr_fat32_probe_top`. Native SDHC SPI CMD17, MBR and FAT32 VBR/BPB parsers, synchronous BSRAM sector buffer, UART; no PicoRV32.
- Local build: `build/run_20261024_095913_693_c293c8/sd03_mbr_fat32_nano9k.fs`.
- SHA-256 verified by operator: `2F5221EA95F91EE27F4B5BD2E10B4738CAF592F2113EC807A0C68433EFBF51A2`.
- Input reports: operator-supplied Icarus test PASS, Gowin build PASS, timing report numbers and a physical UART capture. The assistant had no direct hardware access. Separate programmer command output for this run was not furnished, so do not present SRAM programming log as independently captured.
- UART 115200 8N1. No SD write commands; the prior SRAM-only programming gate explicitly excludes configuration Flash.
- [GitHub RTL CI PASS](https://github.com/AIDevelopersMonster/Sipeed-FPGA/actions/runs/40073096460).

## Physical UART — exact operator capture

```text
SD03 RESULT=MBR_FAT32    VOL=00000040 FAT=00000840 DATA=00004440 ROOT=00004440 CLUS=000EFFDF E=00
```

| Field | HEX | Decimal | Meaning |
|---|---|---:|---|
| RESULT | MBR_FAT32 | — | MBR FAT32 candidate, followed by VBR/BPB validation |
| VOL | 00000040 | 64 | Partition start LBA |
| FAT | 00000840 | 2112 | First FAT LBA |
| DATA | 00004440 | 17472 | Data region start LBA |
| ROOT | 00004440 | 17472 | Root directory's initial cluster LBA |
| CLUS | 000EFFDF | 983007 | Data-cluster count from BPB calculation |
| E | 00 | 0 | No errors reported by SDHC controller |

Derived: reserved sectors = `2112 - 64 = 2048`; the total FAT region = `17472 - 2112 = 15360` sectors. The number of FAT copies and sectors/cluster are not included in the UART; a physical host-side BPB inspection is required before claiming them numerically. The root directory begins with data-cluster 2 according to the validator's geometry. The observed partition begins at **LBA 64**, not LBA 2048 (an address read earlier in SD-02).

## Gowin internal STA (prior operator report, same SHA-256)

| Criterion | Observed |
|---|---:|
| Logic | 2764 / 8640 (32%) |
| LUT, ALU | 2283, 481 |
| FF | 1949 / 6480 (31%) |
| BSRAM | 4% |
| Setup violated endpoints | **0** |
| Hold violated endpoints | **0** |
| Setup TNS | **0.000 ns** |
| Hold TNS | **0.000 ns** |
| First reported worst setup slack | **+15.911 ns** |

The original SD-03.4 bitstream SHA `79CCB71D7CC524B31A5B237127B8E02D959102631EEB027B5299ECF9BC955C55` failed 27 MHz STA with **129 setup violations** and remains excluded. Revised BPB arithmetic uses a multicycle FSM. External SD MISO I/O return-delay characterization is not complete.

## Scope of the functional PASS

The hardware read LBA0, selected an MBR FAT32 candidate, read and checked its partition boot sector, calculated absolute FAT/data/root start LBAs and returned a full diagnostic UART line with no registered SDHC error. These results are credible operator-level functional evidence for the tested board/card and the specified read-only scope.

**Not established:** byte-for-byte independent PC host comparison, FAT directory iteration, cluster-chain traversal, opening/reading files, cross-card portability, full external I/O timing closure, GPT/exFAT support, HDMI or PiKoSoL integration. A syntactically plausible BPB does not prove every FAT entry or stored file is correct.

**Next:** host-side read-only check of partition offset and BPB; then FAT directory and chain reading as a separate lab. Preserve SD-01, SD-02, and PiKoSoL unchanged.

[Initial build and timing history](SD03_BUILD_2026-10-24.md) · [UART transcript](SD03_UART_2026-10-24.txt).
