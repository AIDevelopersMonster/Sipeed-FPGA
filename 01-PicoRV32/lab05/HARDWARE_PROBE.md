# LAB-05.1 — stand-alone microSD hardware probe (no CPU/HDMI)

This is an isolated **diagnostic bitstream candidate**, not the PiKoSoL OS or a release. The known-good PiKoSoL v0.2.0 FPGA firmware and its web loaders are unchanged.

## Expected board behavior

Insert a known-good **SDHC** microSD card (4–32 GB is a convenient first choice) before powering/reconfiguring the board. Firmware never writes the card. On reset, the hardware starts SPI at approx 210.94 kHz, runs CMD0/CMD8/CMD55/ACMD41/CMD58, verifies SDHC, reads 512 bytes at LBA0 with CMD17, validates the received CRC16 and prints exactly one line over the board's USB UART **115200 8N1**:

- Success: **SD PASS SIG=55AA** for a commonly formatted card with a normal MBR or boot-sector signature (the actual four hex digits come from offsets 510/511).
- Failure: **SD ERR=E1** etc. Error-code descriptions are in lab05_sd_init_read0.v. In error mode all six active-low LEDs turn on; on success LED1 turns on.
- S1 button (FPGA pin 3, active low) restarts the test.

A blank or special raw card may produce a different signature even if the sector CRC passes; signature bytes are **observations**, not part of the PASS criterion.

## Schematic and pins

Based on [official Sipeed Tang Nano 9K schematic](https://dl.sipeed.com/fileList/TANG/Nano%209K/2_Schematic/Tang_Nano_9k_3672_Schematic.pdf), FPGA pins:
CLK 52, reset S1 3, TX UART 17, SD CLK 36, CMD/MOSI 37, CS 38, DAT0/MISO 39. SD GPIO bank is 3.3 V. No extra wires are needed for the on-board slot. Old HDMI pins remain untouched in their own baseline design.

## Simulation, then Gowin build

From PowerShell 7 on Windows:

\`\`\`powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
& .\01-PicoRV32\lab05\tools\test_lab05_spi.ps1
& .\01-PicoRV32\lab05\tools\build_lab05_probe.ps1
\`\`\`

The standalone build produces \`lab05/build/probe_*/lab05_sd_probe_nano9k.fs\` and a SHA-256 manifest. It **never programs FPGA**. Check Gowin PnR and timing reports first, then manually program **volatile SRAM** only. Do not flash this diagnostic onto configuration storage; re-loading verified PiKoSoL v0.2.0 restores the original system.

For first hardware acceptance, a useful output includes UART string, LEDs, build path, resource counts, and timing report summary. No write test, FAT32 or PicoRV32/MMIO claim follows from the probe.

## Gate

Source compile and RTL functional simulation are distinct from Gowin PnR/STA and board PASS. This probe validates electrical communication and LBA0 reads before bringing SD into the resource-constrained HDMI system.
