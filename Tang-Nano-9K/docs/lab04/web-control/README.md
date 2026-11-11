# LAB-04.4 — PiKoSoL Web Control & Terminal (hardware-verified)

Browser Web Serial UART control panel for hardware-verified PiKoSoL LAB-04.3.2 v0.2.0 on Tang Nano 9K.

**STATUS: HARDWARE PASS (operator-verified, Tang Nano 9K + CHUWI N100, 23 October 2026).** Real Web Serial commands, LED responses and HDMI GFX/TERM were demonstrated on hardware. This is not an automated multi-platform certification. [Acceptance protocol](../LAB044_ACCEPTANCE_2026-10-23_RU.md).

## Start

1. Flash the verified .fs file to **SRAM only** using [PiKoSoL WebUSB Loader](../web-loader/) on GitHub Pages (FT2232 Interface A). The terminal page itself does not program the FPGA.
2. Close other programs using COM and optionally close the WebUSB tab.
3. Open [PiKoSoL Control Center](./index.html) over HTTPS on GitHub Pages using Chrome or Edge.
4. Click **Подключить COM**, select **USB Serial Port (COMx)** of FT2232 Interface B (not JTAG Debugger), 115200 8N1.
5. Click **Проверить PicoRV32**. Real output from INFO and LED ? confirms the link.
6. Test HELP, LED 3, LED ?, GFX, OBJ B, MOVE J, COLOR G, KEYS. In KEYS, focus the keyboard zone to send raw i/j/k/l without Enter, press T to return to TERM.

## Safety and protocol

- Web Serial on Chromium HTTPS requires explicit user consent and an accessible OS COM port. Interface B must retain its serial driver; WinUSB on JTAG A is separate.
- Line commands use ASCII with CR terminator and up to 47 printable characters; raw KEYS send bytes directly.
- The browser does not implement a fake RISC-V shell. LED feedback only changes when PicoRV32 responds M=xx, C=n or L=n.
- The browser cannot reconstruct the full HDMI framebuffer; view geometry on the attached display.
- Clear browser log is not the same as CLS (clear FPGA terminal VRAM).
- The browser does not write Flash or automatically access USB devices.
- Bitstream requires SHA-256 verification and SRAM-only operation. The existing JTAG programming workflow is separate.

## LAB-04.4 physical acceptance

- **PASS (operator):** Web Serial connection, true PicoRV32 responses, LED control and HDMI GFX.
- **PASS (operator):** COM-port contention was diagnosed: another browser tab owned the serial port; closing it restored access.
- **Not separately certified:** exhaustive reconnection/error/compatibility matrix. Do not claim it without additional test evidence.

Implementation: standalone HTML/CSS/JS, no framework or build step. GitHub repo [AIDevelopersMonster/Sipeed-FPGA](https://github.com/AIDevelopersMonster/Sipeed-FPGA).
