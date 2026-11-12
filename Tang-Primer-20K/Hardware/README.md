# Hardware — Tang Primer 20K + Dock

**State:** identification and pin audit pending.

Expected FPGA: **GOWIN GW2A-LV18**. The exact package, speed grade, board revision, oscillator frequency, I/O voltages and Dock interconnect require confirmation from the physical board and schematic.

Manufacturer/marketing material mentions:
- **20K LUT4-class** logic and **1 Gbit DDR3**;
- **32 Mbit Flash**;
- HDMI, Ethernet 10/100, USB/JTAG/UART, SD, camera and LCD;
- PMOD connectors and other Dock expansion.

This list is **not** a validated inventory or verified pin map of our unit. Some interfaces depend on the Dock and optional peripherals.

Before writing any pin constraint: record board/dock revision, download the matching schematics and pinout, identify USB-JTAG and UART, oscillator and clock domains, and confirm power/I/O banks. Never reuse Tang Primer 25K or Tang Nano constraints by name alone.
