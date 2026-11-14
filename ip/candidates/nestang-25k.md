# NESTang-25K: candidate for IP study

**Status:** INTERESTING CANDIDATE / NOT BOARD VERIFIED HERE.

Upstream: https://github.com/sipeed/TangPrimer-25K-example/tree/main/nestang-25k
Core reference: https://github.com/strigeus/fpganes

This is a complete FPGA NES system, with cycle-oriented NES CPU/PPU/APU, video/HDMI 720p, SD-game loader, memory controller and controller interfaces. Its full Verilog/RTL implementation and prepared `nes.fs.7z` are in the upstream directory.

### Reusable components to review (do not silently treat as portable IP)

- `src/cpu.v`, `src/ppu.v`, `src/apu.v` - NES logic;
- `src/sd_reader.sv`, `src/sd_file_list_reader.v`, `src/sd_loader.v` - SD and game loading;
- `src/memory_controller.v`, `src/sdram.v` - SDRAM path;
- `src/usb_hid_host.v`, `src/usb_gamepad/` - USB/HID candidate;
- `src/nes2hdmi.sv`, `src/hdmi/`, `src/hdmi2/` - HDMI implementation;
- `src/hw_uart.v` - internal UART example.

### Lab constraints

- Upstream `nes_tang25k.v` exposes SDRAM interface and instantiates `MemoryController`. External SDRAM module is not yet present in this lab; **do not expect game launch without it**.
- HDMI/PMOD connection requires exact board pin and module verification.
- Source is linked rather than duplicated: preserving its full dependency tree and licensing is essential for a faithful system import.

**Next action:** evaluate USB Host, SD reader and HDMI as *independent* IP candidates, keeping upstream source paths and commits pinned before modifications.
