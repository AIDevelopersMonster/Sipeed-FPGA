# SD-02: multi-LBA SDHC FPGA reader

Independent Verilog research snapshot for Tang Nano 9K, derived from the experimental LAB-05.2 multi-LBA controller. No CPU, no FAT32 and no SD writes.

Four modeled requests: LBA 0, 1, 2048 (injected bad CRC), and 65541 (recovery after error). Verify all sector CRCs, repeated CMD17 without a second CMD0, all 32 LBA argument bits, and correct busy/done.

From the repository root:

~~~powershell
& .\boards\tang-nano-9k\experiments\sd-multilba\test.ps1
~~~

**Status (24 October 2026): HARDWARE FUNCTIONAL PASS for the defined four-LBA read-only experiment.** Icarus simulation, Gowin build, internal STA, SRAM programming, and operator-reported UART all passed. See [hardware acceptance receipt](acceptance/SD02_HARDWARE_ACCEPTANCE_2026-10-24.md) and [verbatim UART log](acceptance/SD02_UART_2026-10-24.txt). No FAT32 or PiKoSoL integration is claimed. Preserve the previously published SD-01 unchanged.


**Видео аппаратного испытания SD-02.1 (ссылка автора):** [YouTube — Tang Nano 9K, четыре LBA, CRC16, UART HARDWARE PASS](https://youtu.be/KdMJc_Ly7fQ).

## FPGA hardware probe candidate (SD-02.1)

The independent `sd02_multilba_probe_top` is now included. It runs **without PicoRV32** and makes four read-only CMD17 requests: LBA 0, 1, 2048 and 65541. For each successful sector, it independently recomputes **CRC16/CCITT over all 512 bytes read back from BSRAM** and sends:

```text
SD02 LBA=00000000 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00000001 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00000800 CRC=XXXX H=XXXX T=XXXX E=00
SD02 LBA=00010005 CRC=XXXX H=XXXX T=XXXX E=00
SD02 PASS
```

`H` is the first two sector bytes, `T` is the last two; `CRC` is a full-sector diagnostic digest. On a normal card these values depend on the card and format. An error gives `E=XX` and the final line `SD02 FAIL`; failed reads have `CRC/H/T=0`, so they cannot masquerade as valid data. LED1 on means PASS; all six LEDs on means FAIL. The example values above were a pre-test template. The actual user-confirmed UART output is preserved in [the hardware acceptance record](acceptance/SD02_HARDWARE_ACCEPTANCE_2026-10-24.md). The physical experiment returned `E=00` for all four LBAs and `SD02 PASS`.

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

**Evidence:** RTL CI, Gowin local PnR and internal STA, physical SRAM loading and UART transcript were all reported successful by the operator. The device remains read-only. External SD MISO timing and byte-for-byte comparison with an independent PC host have not been certified. No assumption that sectors 2048 or 65541 contain FAT32, or even that the card has a valid filesystem. SDHC/SDXC only and read-only.
