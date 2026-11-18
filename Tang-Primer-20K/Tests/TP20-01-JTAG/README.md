# TP20-01 — JTAG device discovery / Tang Primer 20K Dock

**Result: JTAG SCAN PASS (2026-11-18).** This is a read-only hardware identification test. It does NOT prove working HDMI, DDR3, UART, RISC-V, or an FPGA design.

## Confirmed observation

The following information comes from one operator-supplied PowerShell 7.6.10 session on Tang Primer 20K + Dock:

| Check | Result |
| --- | --- |
| Gowin Programmer CLI: --scan-cables | PASS — USB Debugger A was detected |
| Gowin Programmer CLI: --scan | PASS — one JTAG device found |
| Reported family | GW2A |
| Reported name | GW2AR-18C GW2ANR-18C GW2A-18C (One of them) |
| Reported JTAG ID | 0x0000081B |
| Target cable | Gowin USB Cable (FT2CH), 2.5 MHz |
| Configuration write | NONE |
| HDL synthesis / FPGA firmware / DDR3 / HDMI | NOT TESTED by this test |

**Interpretation:** The tool reports an 18C family group, not the exact fitted chip variant. The precise package/speed grade must be verified from the physical marking and board documentation, not inferred from the JTAG ID alone. The ID shown here is a device identification code, not a user's personal serial number.

## Run the test (Windows / PowerShell 7+)

Prerequisites: Tang Primer 20K Dock connected via its JTAG/programmer USB port; Gowin Programmer installed; no other program holding the programmer.

From this directory, run (adjust the Gowin installation path if needed):

    pwsh -NoProfile -File .\tp20-jtag-scan.ps1 -ProgrammerCli "C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe"

Or, when programmer_cli.exe is already in PATH:

    pwsh -NoProfile -File .\tp20-jtag-scan.ps1

The script executes only **--scan-cables** and **--scan**. No bitstream is loaded; **SRAM and Flash are not written**. A timestamped diagnostic log is saved in the current user's TEMP directory (not in this Git repository). Inspect any log before sharing: USB location, local paths, and other machine-specific metadata may appear.

An anonymized, shortened example of the expected output is provided in [example-output.txt](example-output.txt). The repository intentionally does **not** contain the original raw session log, Windows user profile path, or USB location number.

## Failure and acceptance criteria

- Cable not found: check the USB port, driver, power, and whether Gowin Programmer/another application holds the adapter.
- Cable found but FPGA not found: check Dock power, board configuration and physical connection; do not flash anything to diagnose blindly.
- PASS means that one GW2A-family device was enumerated, and the program exited successfully.
- To advance to HDMI and DDR3, perform **separate** board tests using a known-compatible reference design, initially with volatile SRAM configuration.

**Project classification:** TP20-01 JTAG SCAN PASS. There is no BUILD PASS, STA PASS, or general-purpose FPGA BOARD PASS from this scan.

**Source (manufacturer examples):** https://github.com/sipeed/TangPrimer-20K-example
