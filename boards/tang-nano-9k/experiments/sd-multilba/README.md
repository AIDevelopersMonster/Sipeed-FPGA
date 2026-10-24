# SD-02: multi-LBA SDHC FPGA reader

Independent Verilog research snapshot for Tang Nano 9K, derived from the experimental LAB-05.2 multi-LBA controller. No CPU, no FAT32 and no SD writes.

Four modeled requests: LBA 0, 1, 2048 (injected bad CRC), and 65541 (recovery after error). Verify all sector CRCs, repeated CMD17 without a second CMD0, all 32 LBA argument bits, and correct busy/done.

From the repository root:

~~~powershell
& .\boards\tang-nano-9k\experiments\sd-multilba\test.ps1
~~~

**Status:** Multi-LBA behavioral CI previously PASSED; new hardware-top RTL compilation is checked separately. Physical PnR/STA and board tests are pending. Not yet a hardware-validated or PiKoSoL-integrated design. Retain published SD-01 unchanged: it has its own hardware evidence. If simulation succeeds, next steps are a standalone FPGA hardware probe, Gowin PnR/STA and SRAM-only acceptance.


## FPGA hardware probe candidate (SD-02.1)

The independent `sd02_multilba_probe_top` is now included. It runs **without PicoRV32** and makes four read-only CMD17 requests: LBA 0, 1, 2048 and 65541. For each successful sector, it independently recomputes **CRC16/CCITT over all 512 bytes read back from BSRAM** and sends:

```text
SD02 LBA=00000000 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00000001 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00000800 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00010005 CRC=XXXX H=XXXX T=XXXX E=00
SD02 PASS
```

`H` is the first two sector bytes, `T` is the last two; `CRC` is a full-sector diagnostic digest. On a normal card these values depend on the card and format. An error gives `E=XX` and the final line `SD02 FAIL`; failed reads have `CRC/H/T=0`, so they cannot masquerade as valid data. LED1 on means PASS; all six LEDs on means FAIL. The test output is **not yet a real hardware observation**.

From repository root (PowerShell 7, Windows):

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git fetch origin
git switch agent/lab05-sd02-multilba
git pull --ff-only

& .\boards\tang-nano-9k\experiments\sd-multilba\test.ps1
& .\boards\tang-nano-9k\experiments\sd-multilba\build.ps1
```

`build.ps1` emits a uniquely named `build/run_*/sd02_multilba_nano9k.fs`, its SHA-256, an input manifest and Gowin logs. It **does not program any device**. First inspect logic utilization, PnR/STA setup and hold, constraints and the output SHA-256. If these are clean, use the **previously accepted SRAM-only** programmer `01-PicoRV32/lab04/tools/program_lab04_sram.ps1 -Bitstream <ABSOLUTE_SD02_FS> -Program`; this does not write configuration Flash. Close competing JTAG/WebUSB clients. Insert SDHC before powering the FPGA and view serial TX at 115200 8N1. Physical S2 on the tested board restarts the probe.

**Evidence gate:** existing GitHub CI is RTL-level only (even after the new top compilation). Real `.fs` PnR and STA need your Gowin toolchain; the physical UART string must be reported by the operator. No assumption that sectors 2048 or 65541 contain FAT32, or even that the card has a valid filesystem. SDHC/SDXC only and read-only.
