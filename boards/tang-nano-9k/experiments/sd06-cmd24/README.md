# SD-06 — Tang Nano 9K standalone SDHC Read/Write

**Status (2026-10-25): HARDWARE READ / WRITE / RESTORE PASS for one qualified scratch LBA (10718).** Firmware in SRAM, UART 115200 8N1 over COM10, SPI CMD17 and CMD24 with real SDHC test card. Software uses preimage compare, CRC16, single-LBA hardware write permission, postwrite CMD17 verification. Full FAT32 file write/creation on FPGA is not implemented.

**Verified evidence:** [hardware acceptance receipt](acceptance/SD06_RW_HARDWARE_2026-10-25.md), [complete implementation and limits](README_RW.md).

**Hardware PASS is scoped:** exactly one disposable-card 512-byte scratch sector, written and restored successfully. No broad multi-card endurance/recovery/speed test, no PiKoSoL CPU+HDMI integration, no proof of full external SPI/UART IO STA.

## Reproduce offline / inspect implementation

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git pull --ff-only
$sd = '.\boards\tang-nano-9k\experiments\sd06-cmd24'
& "$sd\test.ps1"
```

Use the reviewed read-only firmware and `hw_read_gate.ps1` for read-only operation. A write-capable bitstream is **only** for the same disposable SDHC test card with an approved and verified `SDRWTEST.BIN` scratch LBA and preimage manifest. Do not reuse the compiled LBA 10718 permission on other cards.

## Historical design

The previous design-only plan is archived in Git history. CMD24 engine, combined UART+SPI top, host tools and separate safe build scripts are now implemented and have passed their documented narrow hardware test. Keep the tested hardware receipt immutable.
