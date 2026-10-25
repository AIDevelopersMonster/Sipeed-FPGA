# SD Read/Write — hardware acceptance, Tang Nano 9K (2026-10-25)

**Status: PASS for the tested configuration.**

This is an acceptance receipt transcribed from the operator's console output,
not an assertion of independent access to the physical board or a general
certification for arbitrary SD cards/sectors. The host-side FAT32 parser is
not an FPGA filesystem implementation.

## Hardware and implementation

- FPGA board: Sipeed Tang Nano 9K, GW1NR-9C.
- System fabric clock: 27 MHz.
- Data path: PC / COM10 / UART 115200 8N1 -> FPGA sector bridge -> SDHC SPI.
- Commands: CMD17 read 512-byte sector; CMD24 write 512-byte sector.
- FPGA protection in the tested write-enabled image: **only LBA 10718**
  (compile-time `WRITE_FIRST_LBA = WRITE_LAST_LBA = 10718`).
- FAT32 file on disposable test card: `SDRWTEST.BIN`, size 512 bytes,
  FAT32 cluster 11, physical sector LBA 10718.
- Only volatile FPGA SRAM was programmed; Flash programming not requested.
- No FAT32 FAT, directory or partition metadata was intentionally written.
- Standalone controller; **no PiKoSoL PicoRV32 + HDMI integration yet**.

## Reproducibility and image identity

| Artifact | Value |
|---|---|
| Working branch | `feature/sd06-cmd24-offline` |
| Locked-read firmware | `build/rw_20261025_090025_346/sd06_rw_nano9k.fs` |
| Locked-read firmware SHA-256 | `98CED68AA1ED5DBCD91BA6670E137771CDED816254760D24223485E2D05EC2FF` |
| Hardware CMD17 read LBA 0 SHA-256 | `3F74254E7991D8DF616EB040D0A5424FEAC7F4AF3ED2512FC7031DF216CE9980` |
| One-LBA RW firmware | `build/scratch_20261025_091806_636/sd06_scratch_SINGLE_SECTOR.fs` |
| One-LBA RW firmware SHA-256 | `694D9526525B8AEF99126AF5EF73D7A85216658E707482342521AD035E34F109` |
| Sector backup | `_reports/sd_rw_scratch/preimage.bin` |
| Sector manifest | `_reports/sd_rw_scratch/manifest.json` |

The working bitstream and manifest paths above are **local operator paths**,
not files included in this GitHub receipt. Do not claim the binary `.fs`
is archived in GitHub unless separately committed.

## Operator results (real SDHC media)

| Operation | Observed result |
|---|---|
| Offline Python | 16 tests, PASS on the reported run |
| UART/CMD17/CMD24 integration simulation | PASS, mock SD card |
| CMD24 byte-SPI model | PASS, mock SD card |
| Gowin PnR, single-LBA write-enabled image | `SD_RW_SCRATCH_BUILD_STA_PASS: LBA=10718` |
| Physical read-only merged image | `SD_RW_READ_ONLY_HARDWARE_PASS` |
| Scratch FAT32 identification | `SD_RW_SCRATCH_INSPECT_PASS: LBA=10718 CLUSTER=11` |
| Scratch-card/sector preflight | `SD_RW_SCRATCH_PREFLIGHT_PASS: LBA=10718` |
| Real CMD24 write and internal CMD17 verification | `SD_RW_HW_WRITE_VERIFY_PASS: LBA=10718 BYTES=512` |
| Real CMD24 restoration and CMD17 verification | `SD_RW_HW_RESTORE_VERIFY_PASS: LBA=10718 BYTES=512` |

## Sector data evidence

1. **Original:** `D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3`
   (SHA-256 of 512-byte file on PC and copied FAT32 SD card, plus FPGA
   `preimage.bin` backup).
2. **After real CMD24:** `C934134A8F462557E29357920CFF96314FEBC5E363AF26A8F37ACD33E4B155A2`
   (FPGA CMD17 readback, 512-byte exact equality).
3. **After restoration with real CMD24:**
   `D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3`
   (FPGA CMD17 readback, exact equality with original 512-byte backup).

Thus, two **successful real-media CMD24 transactions** were reported:
test-pattern write and exact original-sector restoration. The result
confirms reversible single-sector write in the tested configuration.

## PnR resource context (separate earlier measurement-only build)

The earlier full-RW measurement-only wrapper (different from the write-enabled
scratch image) reported: 1937/8640 logic elements (23%), 662 FF (10%),
3 SDPB BSRAM (12%), internal Fmax 57.230 MHz, worst setup slack +19.564 ns,
worst hold slack +0.443 ns, zero internal setup/hold violations, 27 MHz clock.
These exact resource numbers **must not** be attributed to the final
scratch-enabled bitstream without reading its own PnR report.

## Qualification boundary and closure

**Closed:** standalone PC-controlled raw sector **read, guarded write,
readback and restore** on Tang Nano 9K, at a proven single physical LBA,
with SRAM loading and verified backup of that sector.

**Not established:** write access to arbitrary sectors or media, full
SDHC/SDXC compatibility, performance envelope, power-loss handling,
external SPI/UART I/O STA, long-term endurance or persistent storage
reliability, full-card image backup verification, filesystem writes, or
a combined PicoRV32 + HDMI + SD build.

**Next distinct task:** minimal PiKoSoL memory-mapped CMD17/CMD24 block
controller (no extra UART; 512-byte sector buffer and CPU MMIO), with
Gowin PnR/STA and **separate** hardware acceptance on 9K or 20K.
Do not restart successful standalone tests unless integration introduces
a new, specific failure.
