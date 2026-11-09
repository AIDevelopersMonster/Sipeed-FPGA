# PiKoSoL 20K — PicoRV32 native port

**Development branch only — source/architecture stage, NOT a working bitstream, not BOARD PASS.**

Purpose: evolve the hardware-confirmed PiKoSoL 9K v0.2.0 on Tang Nano 20K **with PicoRV32**. Systems on VexRiscv or other processors have separate identities (TexKonSol or a later chosen name). The board-confirmed VexRiscv EX20-05.16 remains unchanged and is a separate reference demonstration.

**Critical product decision:** port the functions, algorithms and user command contract, **not the resource restrictions** of GW1NR-9C:
- Do **not** present the 9K's 640x480 HDMI viewport as the final design. Tang Nano 20K uses **native 1280x720** HDMI.
- Do **not** carry over the 9K 16 KiB boot ROM / 1 KiB scratch RAM sizes as product maxima. Use adequate configurable on-chip memory and introduce the board's 8 MiB SDRAM.
- Do **not** make two hard-wired rectangles the full graphics API. Use a parameterized descriptor list, and scale after PnR.
- Do **not** make 27 MHz an immutable CPU limit: it is a reasonable compatibility/initial simulation clock only; separately qualify faster system clock(s) with actual STA.
- Preserve the tested 9K firmware commands and data formats at a **compatibility API**, not necessarily as immutable physical register addresses.
- SD is SPI-mode, read-only first. All configuration loading into FPGA is **SRAM only**; never overwrite configuration Flash or blindly overwrite an SD volume.

## Intended functionality

| Capability | Target | Evidence now |
| --- | --- | --- |
| CPU | PicoRV32, RISC-V RV32I; adjustable CPU clock | Original 9K: BOARD PASS. 20K: NOT TESTED |
| HDMI | 1280x720 @60 nominal | DVI/HDMI vendor path has BOARD PASS in EX20-05.16 with different CPU; no PicoRV32 integration yet |
| TERM | Native 160x60 characters with 8x12 font, scrolling and input | Original 9K: 76x32 backing store; native engine not built yet |
| GFX | Parameterized, frame-snapshotted object descriptors | Original 9K: 2 objects; expanded engine not built yet |
| LEDs | Six active-low physical LEDs, software-controlled | Original 9K: BOARD PASS; 20K physical pins known |
| RGB | Onboard WS2812 | Supported by external LiteX reference; not built yet |
| SD | SPI card read, FAT32 file read, no write until separately authorized | Not integrated |
| Memory | 8 MiB board SDRAM where useful; BRAM for low-latency metadata/terminal | SDRAM controller integration not built |
| Shell | PiKoSoL interactive parser, HELP/INFO/LED/GFX/TERM etc. | Original 9K ROM is reusable as a behavioral reference; not a drop-in complete 20K image |

## Existing reusable sources

- [PiKoSoL 9K software and validated board evidence](../../../../docs/lab04/README.md)
- [9K PicoRV32 core and original Wishbone-free MMIO](../../../../01-PicoRV32/lab04/rtl/lab04_cpu_soc.v)
- [9K command shell ROM assembly](../../../../01-PicoRV32/lab04/firmware/lab04_boot.S)
- [9K graphics overlay](../../../../01-PicoRV32/lab04/rtl/lab04_graphics_osd.v)
- [9K HDMI terminal](../../../../01-PicoRV32/lab04/rtl/lab04_console_osd.v)
- [9K UART CDC and graphics mailbox](../../../../01-PicoRV32/lab04/rtl/lab04_tty_byte_cdc.v)
- [EX20-05.16 proven 720p PHY/PLL source](../EX20-05-CPU-HDMI/EX20-05-16_RELEASE.md)

## Native architecture and acceptance

See [ARCHITECTURE.md](ARCHITECTURE.md) for the 720p graphics, terminal, memory map and five-gate first hardware demonstration. The previous 640x480-in-720p idea is **explicitly rejected as the target**. There is **no published .fs**, and no claimed build/STA/hardware success.

## Safety and provenance

All prior 9K and 20K confirmed bitstreams are immutable references. Vendor DVI IP is fetched using the pinned Sipeed commit from EX20-05.16 and is not redistributed here. Any new PnR needs board pins, recovery/removal, clock-domain crossings, actual Fmax and resource fits validated. The correct two-channel FTDI cable may be temporarily unavailable while MobaXterm holds an interface; close all COM/JTAG clients before Gowin SRAM programming.
