# SD-06 standalone SDHC RW — hardware acceptance receipt

Date: **2026-10-25**  
Operator-supplied evidence: PowerShell terminal outputs shared in ChatGPT conversation.  
Repository: `AIDevelopersMonster/Sipeed-FPGA`, branch `feature/sd06-cmd24-offline`.

## Test environment

- Board: Sipeed Tang Nano 9K, GW1NR-9C.
- Transport: UART COM10 / SDHC SPI; physical card is a disposable FAT32 microSD.
- GPIO/SRAM Gowin programming; no configuration flash writes.
- Physical read/write unit: one 512-byte sector.
- Scratch file on FAT32 volume: `SDRWTEST.BIN`, size 512, cluster 11, physical **LBA 10718**.
- Compile-time hardware permission: `WRITE_FIRST_LBA=10718` and `WRITE_LAST_LBA=10718`, all other LBA writes denied.
- Test image: `build/scratch_20261025_091806_636/sd06_scratch_SINGLE_SECTOR.fs`.
- Test image SHA-256: `694D9526525B8AEF99126AF5EF73D7A85216658E707482342521AD035E34F109`.

## Observed results

| Check | Operator result |
|---|---|
| Offline Python suite | 16 tests PASS (from preceding qualification log) |
| Combined UART CMD17/CMD24 mock, CRC and fault guards | PASS |
| Full RW isolated 9K PnR/internal STA | PASS; earlier full measurement 1937 / 8640 logic (23%), BSRAM 3 SDPB (12%), setup +19.564 ns, hold +0.443 ns |
| Read-disabled-write combined bitstream on board | CMD17 LBA 0 PASS; SHA-256 `3F74254E7991D8DF616EB040D0A5424FEAC7F4AF3ED2512FC7031DF216CE9980` |
| Scratch file identity from FPGA FAT32 read | LBA 10718, cluster 11, 512 B, PASS |
| Scratch preflight | PASS; no writes performed |
| One-sector scratch-enabled PnR/internal STA | `SD_RW_SCRATCH_BUILD_STA_PASS: LBA=10718` |
| Physical CMD24 update + CMD17 readback | **PASS** |
| Physical CMD24 original-sector restore + CMD17 readback | **PASS** |

**Original 512 B SHA-256:**  
`D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3`

**Written 512 B SHA-256 (physical readback):**  
`C934134A8F462557E29357920CFF96314FEBC5E363AF26A8F37ACD33E4B155A2`

**Restored 512 B SHA-256 (physical readback):**  
`D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3`

The final sector matches its original full-byte preimage and SHA-256. Operator output:

```text
SD_RW_SCRATCH_PREFLIGHT_PASS: LBA=10718 ORIGINAL_SHA256=D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3
SD_RW_HW_WRITE_VERIFY_PASS: LBA=10718 BYTES=512 SHA256=C934134A8F462557E29357920CFF96314FEBC5E363AF26A8F37ACD33E4B155A2
SD_RW_HW_RESTORE_VERIFY_PASS: LBA=10718 BYTES=512 SHA256=D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3
```

## Scope and limitations

**PASS means** successful physical read, write, readback and restoration of one FAT32 file data-sector on a single SDHC card with the documented bitstream. It is not a proof of universal sector write capability on every card; not a performance/endurance/power-loss test; not independent certification of full external SPI/UART timing; not full FPGA FAT32 file-write support; and **not** a resource/timing test of the eventual CPU+HDMI PiKoSoL integration.

The bitstream with fixed LBA 10718 must not be treated as general-purpose or shared blindly with other cards. Different cards may have unrelated metadata at that LBA; reuse could destroy data. The safe default in `build_rw.ps1` remains WRITE DISABLED (0..0).

## Acceptance decision

**SD-06 standalone hardware read/write functional acceptance: PASS (qualified one-sector case).** Freeze this evidence. Next independent design decision is whether to integrate a minimal 512 B CMD17/CMD24 MMIO block into the existing PiKoSoL CPU+HDMI build and measure combined PnR/STA.
