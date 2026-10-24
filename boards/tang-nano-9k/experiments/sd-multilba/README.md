# SD-02: multi-LBA SDHC FPGA reader

Independent Verilog research snapshot for Tang Nano 9K, derived from the experimental LAB-05.2 multi-LBA controller. No CPU, no FAT32 and no SD writes.

Four modeled requests: LBA 0, 1, 2048 (injected bad CRC), and 65541 (recovery after error). Verify all sector CRCs, repeated CMD17 without a second CMD0, all 32 LBA argument bits, and correct busy/done.

From the repository root:

~~~powershell
& .\boards\tang-nano-9k\experiments\sd-multilba\test.ps1
~~~

**Status:** SIMULATION GATE PENDING. Not yet a hardware-validated or PiKoSoL-integrated design. Retain published SD-01 unchanged: it has its own hardware evidence. If simulation succeeds, next steps are a standalone FPGA hardware probe, Gowin PnR/STA and SRAM-only acceptance.
