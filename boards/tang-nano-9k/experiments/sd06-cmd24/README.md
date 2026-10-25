# SD-06 — isolated CMD24 sector-write experiment

**DESIGN ONLY. No write-capable RTL, bitstream, physical write, or card modifications exist yet.**

SD-05 read-only bitstream and FAT32 Python reader remain frozen.

## Safe design gates

1. Dedicated expendable SDHC card, never the accepted SD-05 microSD.
2. Complete independently verified backup outside that card, capacity and card identity recorded.
3. Select an explicitly reserved scratch LBA outside partitions and filesystem metadata. Never assume a free cluster is safe for raw sector writes.
4. Two-stage operator workflow: read-only plan, then separately authorized commit with explicit acknowledgement, card identity match, sector preimage SHA-256 and permitted LBA.
5. Implement write only in an independent FPGA top: 9-byte request command W plus 512-byte payload and frame CRC, host-side bounds and sequence validation, negative tests for malformed/partial frames. No changes to existing read-only bitstream.
6. SD SPI CMD24 response R1, start token FE, 512 bytes, CRC16, data response accepted code, bounded busy wait; issue CMD17 verification and compare all 512 bytes.
7. SRAM-only programming; never configuration Flash. All hardware write tests require intentional explicit user authorization and backed-up disposable card.
8. Stop after 2–3 documented physical failures, diagnose electrical interface rather than repeatedly rewriting logic.

## Milestones

- SD06-A: offline protocol and simulated CMD24 card model; no actual writes.
- SD06-B: RTL integration mock, negative tests and bounds.
- SD06-C: Gowin STA and input hashes for an isolated SRAM candidate.
- SD06-D: explicitly authorized disposable-card single-sector write and CMD17 read-back; restore/verify backup.
- SD06-E: evaluate whether FAT32 mutation semantics are actually needed; raw sector write alone is not safe creation of FAT32 files.

**Status:** all milestones pending. No CMD24 activation is authorized by this document.
