# PR20-00 — Tang Primer 20K Board Bring-up

**Status: NOT TESTED.** No project/bitstream is published here yet.

## Minimum functional test

1. Photograph and transcribe FPGA marking, Dock revision, clocks and any installed memory.
2. Confirm USB/JTAG detection and supported Gowin programmer/EDA version.
3. Find pin constraints **from this revision's original schematics**.
4. Program a disposable design into volatile configuration memory where safe; leave Flash untouched.
5. Test LED and a known clock; then TX-only UART/loopback once pinout is confirmed.
6. Optionally test BRAM and available external DDR3 only after clock and memory parameters are validated.
7. Record bitstream identity, build logs, STA, actual test and results independently.

## Report template

- Board/Dock revision:
- Exact FPGA marking:
- Power, USB/JTAG and COM port:
- Clock source and configured frequency:
- Gowin EDA version:
- Design source commit:
- Constraints source/revision:
- Programming target: SRAM only / other:
- LED observation:
- UART observation:
- BUILD PASS: not evaluated
- STA PASS: not evaluated
- BOARD PASS: not evaluated

A published example is not a laboratory test result.
