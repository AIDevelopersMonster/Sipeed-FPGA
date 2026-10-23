# PiKoSoL LAB-05.1 — microSD SPI research branch

Status: **RTL prototype ONLY**. Nothing in this folder is hardware-qualified or integrated into the verified LAB-04.4 bitstream. No SD FAT32, sector read, CID/CSD, firmware changes or physical PASS are claimed.

## What exists now

* `rtl/lab05_spi_byte.v`: synthesizable SPI mode-0 single-byte master with a **single 27 MHz system clock domain**; SCK is a clocked output, not an internal clock domain.
* `tests/tb_lab05_spi_byte.v`: self-checking loopback test; verifies four bytes and eight SCK pulses per byte.
* `tools/test_lab05_spi.ps1`: Icarus Verilog test command for Windows/PowerShell 7.
* `tools/resource_preflight.ps1`: locates the actual Gowin synthesis/PnR reports of the existing LAB-04 baseline and prints extracted capacity/use candidates; resource occupancy is **unknown until inspected**.

## Run the first model check (Windows)

```powershell
cd C:\GitHub\Sipeed-FPGA
& .\01-PicoRV32\lab05\tools\test_lab05_spi.ps1
& .\01-PicoRV32\lab05\tools\resource_preflight.ps1
```

No board programming is performed by these scripts.

## Board / interface design

* The official Tang Nano 9K schematic and pinout **must** be checked for the particular board revision before constraining SD pins. Candidate SPI nets are TF CLK, CMD, DAT0 and DAT3. No existing LAB-04 CST file is modified.
* Logic uses `clk` (27 MHz); a divisor emits SPI SCK. Default HALF_PERIOD=64, approximately 210.94 kHz. This is suitable as a conservative initial clock for SPI-mode card reset/initialization; fast-mode operation is out of scope.
* SPI uses 3.3 V SD signalling, no 5 V connections.
* Next: command sequencer CMD0/CMD8/ACMD41/CMD58, timeouts, CRC7, CMD17, 512-byte sector read, plus RTL simulation with a card model. Subsequent step: MMIO integration with PicoRV32 and ROM command `SD INFO`.
* Preserve `pikosol-v0.2.0`: no writes to the baseline RTL, firmware, HDL constraints, bitstream, release or GitHub Pages assets until independent synthesis/STA and hardware acceptance.

## Gate policy

| Gate | Current result |
|---|---|
| Source added | yes |
| Icarus RTL test actually run | **PENDING** |
| Gowin resource/PnR and STA | **PENDING** |
| Physical SD card | **PENDING** |
| ROM / shell integration | **PENDING** |

Use actual validated reports, never infer LUT/BSRAM usage from the capacity figure alone.
