# PR25-00 — Board Bring-up

**Status:** NOT TESTED. No bitstream published.

Acceptance sequence:
1. Record FPGA part and Dock revision.
2. Identify supported Gowin device/toolchain configuration.
3. Confirm JTAG detection and safe SRAM-only programming.
4. Exercise clock/PLL and LED without modifying Flash.
5. Verify UART loopback or a small TX/RX design if pins are confirmed.
6. Exercise internal BRAM using read/write patterns.
7. Archive synthesis, P&R and STA reports separately from board observations.

BOARD PASS requires direct on-board evidence and a matching design/build identifier.
