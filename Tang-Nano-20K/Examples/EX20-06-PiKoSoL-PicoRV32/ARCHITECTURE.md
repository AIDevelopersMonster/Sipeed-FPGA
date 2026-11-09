# PiKoSoL 20K — native architecture contract (design, NOT validation)

## Decisions

1. **CPU identity:** PicoRV32 remains the PiKoSoL processor. We can use its already proven 9K ISA/command behavior as regression oracles. VexRiscv/LiteX is a separate TexKonSol-class design.
2. **Display:** deliver a native 1280x720 raster with the same Sipeed DVI_TX_Top / TMDS_rPLL / CLKDIV sources pinned and exercised by EX20-05.16. Pixel clock and sync timings are subject to exact model and PnR validation.
3. **Composite, don't brute-force:** instead of requiring a raw 24-bit 720p framebuffer, rasterize color background, graphical objects and text in the FPGA. For 720p 60 Hz, raw RGB888 active-pixel reads would require ~165.9 MB/s *before* SDRAM overhead; a naive CPU-driven framebuffer is not a reasonable first requirement. Implement any future DMA with measured burst bandwidth and line buffering.
4. **Text:** a full 1280/8 by 720/12 = **160 columns x 60 lines** is addressable with 8x12 ASCII glyphs; 9600 bytes for one 8-bit text plane, excluding metadata. Use synchronous inferred BSRAM and clean frame/pixel pipeline. Scroll by row mapping/ring rather than copying screen contents.
5. **Graphics:** programmable object table (parameterized count, rather than fixed two). At least 11-bit X, 10-bit Y and width/height dimensions; RGB888 colors and compositing priority. Stage updates on CPU interface; commit a coherent snapshot at frame boundary; preserve stable descriptors across pixel-only resets.
6. **Memory:** use block RAM for predictable core boot, text and object metadata. Use existing 8 MiB on-board SDRAM for programs, assets and file buffers after proven controller integration. No fixed 9K 1 KiB RAM product limit.
7. **Peripherals:** on-board LEDs active-low (FPGA pins 15–20), WS2812 pin 79, UART RX pin 70 / TX pin 69, SD SPI CLK=83 MOSI=82 CS=81 MISO=84, 27 MHz board crystal pin 4. HDMI differential pairs 33/34, 35/36, 37/38, 39/40. These are **board target pins**, not a completed Gowin CST.
8. **SD first pass:** SDHC/SDXC SPI initialization at slow clock, CMD17 one-sector read from a disposable FAT32 test card, then directory/file reading using an existing FAT32 library or audited 9K read-only parser. SD write disabled until explicit dedicated test.
9. **User compatibility:** retain `PiKoSoL>` command names (HELP INFO MEM STATUS LED GFX TERM CLS OBJ MOVE COLOR SIZE PANEL KEYS) with compatible effects. Avoid embedding the entire old fixed-address assembly ROM without updating its memory, dimensions and video ABI.

## Memory and ABI outline (proposed, not frozen until synthesis)

| Region | Meaning |
| --- | --- |
| 0x0000_0000 | CPU boot ROM (size to be set from actual firmware, not fixed at 16 KiB) |
| 0x0001_0000 | BSRAM scratch/application state, expandable |
| 0x2000_0000 | GPIO LED mask (legacy compatibility alias possible) |
| 0x2000_0010..1F | UART TX/RX and status (legacy compatibility possible) |
| 0x2001_0000.. | New video control and scalable object descriptor window |
| 0x2002_0000.. | SD-SPI control/status window |
| 0x4000_0000..0x407F_FFFF | Board 8 MiB SDRAM, after SDRAM controller acceptance |

No hardware writes should be issued to proposed addresses until the running SoC advertises an expected device ID / address map. The initial 9K `0x20000100` video address was designed for only two objects and can be supported as a software API adapter rather than the native hardware ABI.

## Five first-board gates

1. **Source/references:** frozen 9K/EX20-05.16 sources and exact board/pin/PLL provenance; native 720p output design.
2. **Simulation:** PicoRV32 CPU receives UART commands, LED register responds, native 720p video timing/graphics are simulated (no claims about physical output).
3. **Build:** clean Gowin synthesis + PnR + STA for GW2AR-LV18QN88C8/I7, resource and clock domain checks; only then publish candidate hash.
4. **Board:** configure only SRAM via verified Gowin CLI; assert PicoRV32 banner, full native HDMI raster and interactive control of LED + graphics with a hardware evidence log.
5. **SD:** one-sector read + FAT32 file read on an expendable test card, *no writes*. If this cannot be achieved, retain gate 4 as a discrete release and defer SD; never regress known EX20-05.16.

## Working policy

This branch is **not a release**. It holds architecture and future native implementation; test reports will be added only after running real simulations, Gowin, and board. Avoid inventing PLL timings and do not put a 640x480 crop into the final architecture merely because it was present on Nano 9K. Use specific observed evidence at every gate.
