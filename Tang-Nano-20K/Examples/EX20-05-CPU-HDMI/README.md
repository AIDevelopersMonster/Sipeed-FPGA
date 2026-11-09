# EX20-05 / Stage A — RISC-V-controlled HDMI overlay

**Status: RTL SOURCE AVAILABLE / SIM NOT YET VERIFIED / BOARD NOT TESTED.**

This is the first component for a *new* SoC combining the VexRiscv/LiteX architecture and Sipeed's validated HDMI path. It is **not** a working integrated FPGA image. EX20-01 independently confirmed an HDMI pattern on the board; LAB-20.6 independently confirmed native RISC-V firmware execution in the factory LiteX. The two images cannot run simultaneously.

## CPU-to-video contract

`rtl/video_wb_overlay.v` implements a small 32-bit Wishbone B4 register slave on `cpu_clk`, with an independent `pix_clk` raster output. The base address is assigned by the eventual SoC; **none of the factory LiteX CSR addresses can be assumed free or reused**. Byte offsets:

| Offset | R/W | Purpose |
|---|---|---|
| 0x00 | R | signature `0x56323031` |
| 0x04 | RW | background RGB888 `0x00RRGGBB` |
| 0x08 | RW | rectangle X low 16 bits, Y high 16 |
| 0x0C | RW | width low 16 bits, height high 16 |
| 0x10 | RW | rectangle RGB888 |
| 0x14 | R | status bit 0 BUSY; bit 1 ACK toggle |
| 0x18 | W | write bit0=1 to COMMIT staged values |
| 0x1C | R | module version 0x00010000 |

The CPU writes *staging* registers, then COMMIT. A toggle handshake crosses from CPU to pixel clock; the pixel side applies the complete state **at a video frame start**, and acknowledges back. While BUSY, CPU writes to staging registers or COMMIT return bus error. Only full-word byte-enable writes are supported. RGB is zeroed outside active video. Pixel coordinates must be active-region 0-based coordinates supplied by the raster timing generator.

The current module provides **one solid rectangle and a solid background only**; it is not a framebuffer. No external SDRAM bandwidth is needed for video. Geometry/colour update is coherent at the frame boundary, so no partial-frame tearing due to register update is intended.

## Integration requirements (not completed)

1. Establish a reproducible LiteX/VexRiscv source/board target and pin/clock/SDRAM constraints for GW2AR-18C, retaining factory boot only as a reference.
2. Bridge the system Wishbone master to this peripheral, allocate a documented non-overlapping `VIDEO_BASE`, and derive correct `wb_adr_i` byte offsets. Run bus/CDC simulations with independent clocks and reset behavior.
3. Connect existing Sipeed 1280x720 raster timing + tested DVI/TMDS chain; **reuse licensed/reference code by linking to upstream**, not copying opaque artifacts without checking licensing.
4. Confirm PLL output frequencies, reset sequencing, 720p/60 timing, timing closure, pin constraints and hardware device resources with Gowin.
5. Compile `firmware/video_demo.c` using the generated SoC header, load it according to the **new** BIOS/memory map and run on a temporary FPGA SRAM configuration. Do not issue video MMIO writes to factory LiteX.
6. First hardware evidence: unique video signature, CPU-controlled colour change and moving rectangle, UART diagnostics, and restoration after power-cycle.

### Reset and CDC conditions

Both resets must be asserted during startup. Multi-bit stage signals are held constant while a COMMIT is in flight; they are captured in the pixel clock domain on `frame_start` after a two-flop toggle synchronization. This **requires timing/CDC review and simulation**; tool-specific synchronizer recognition/false paths must be audited during synthesis. The sample does not directly provide `HSYNC`, `VSYNC`, pixel PLL or `TMDS` signals.

### What is and is not proven

- **Proven independently on hardware:** Tang Nano 20K factory LiteX RISC-V and Sipeed HDMI EX20-01.
- **Not proven yet:** this RTL module's simulation, integration, successful build/STA, actual CPU-to-HDMI graphics, peripheral address map.
- **Flash policy:** SRAM-only for every experimental FPGA bitstream; do not modify factory nonvolatile configuration.

Upstream video source: https://github.com/sipeed/TangNano-20K-example/tree/main/hdmi
