# EX20-01 HDMI — CLI SRAM program and JTAG operator evidence (2026-11-09)

**Status: SRAM PROGRAM CLI EXIT 0 / HDMI VIDEO NOT YET CONFIRMED.** Evidence comes from the operator's PowerShell transcript, not from independent access to the board.

## Firmware fingerprint
- Source: official Sipeed TangNano-20K-example `hdmi/hdmi.fs`
- Local filename: `sipeed_hdmi_20k.fs`
- File size: **4,619,320 bytes**
- SHA-256: `cb024d255692321a9b7fa22cf603dd89d1cd7875930ad57e00fd2bccf6cf9b0a`

## Operator-reported real-board results
- Programmer log: `C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-01-HDMI\artifacts\HDMI_PROGRAM_20261109_054645.txt`
- CLI result: `SRAM PROGRAM CLI EXIT 0. This is not yet HDMI BOARD PASS: verify screen + key + power cycle + LiteX BIOS.`
- Scan command: `program_hdmi_sram.ps1 -Scan`
- Scan log: `C:\GitHub\Sipeed-FPGA\Tang-Nano-20K\Examples\EX20-01-HDMI\artifacts\HDMI_SCAN_20261109_054700.txt`
- JTAG cable: `Gowin USB Cable(FT2CH)/0/0/null@2.5MHz`
- Family: `GW2A`
- Reported name: `GW2AR-18C GW2ANR-18C GW2A-18C (One of them)`
- JTAG ID: `0x0000081B`
- Found: **1 device**

The JTAG scan lists a compatible device group and does not uniquely identify the exact GW2AR package or speed grade. Programmer exit zero supports successful execution of the configured SRAM programming operation, not actual working HDMI signal.

## Remaining EX20-01 acceptance
1. Observe stable color-bar / pattern on connected HDMI monitor, ideally monitor reports 1280x720.
2. Press configured test-pattern key and observe one or more visible changes.
3. Power cycle the board and check that the original factory LiteX BIOS prompt `litex>` returns on UART.
4. Save screen/photo or monitor details and programming transcript for final hardware receipt.

Do not assert EX20-01 BOARD PASS until physical video evidence and restoration test are available. Do not write FPGA Flash.
