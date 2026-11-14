# PiKoSoL 25K TERM-DVI v0.1 — engineering candidate

**Target:** Tang Primer 25K + Dock, GW5A-LV25MG121NES. `UART RX -> text BRAM -> 720p DVI`, **no processor and no external SDRAM**.

## Status (2026-11-14)

- Source integrated with vendor-derived PLL, DVI encoder and PiKoSoL font.
- **NOT BUILT, NOT PROGRAMMED, NOT BOARD-VERIFIED.** The source is an engineering candidate, not a tested firmware.
- On-board HDMI output is *not* used; connect Sipeed DVI PMOD to the pins mapped in `pins.cst`. Physical connector alignment still must be checked. Previous HDMI test had no image.
- Configuration Flash is not required. Use only `SRAM Program` for the first run.

## Features in this initial candidate

- Video: 1280x720 @ 60 DVI signal; centered native 640x480 character raster, 80x30 characters and 8x16 font.
- UART: RX 115200 8N1, FPGA B3; incoming printable ASCII writes to screen; CR, LF and backspace supported. The TX line C3 remains idle in this version.
- Initial top line: `PiKoSoL 25K TERM-DVI`.
- No scrolling (wraps from last line to line 1); no ANSI escape sequences, command parser, GFX or fonts beyond ASCII 0-127.
- Pixel pipeline latency can shift origin by ~2 pixel clocks; accepted only for first bring-up.
- Two output LED signals reflect PLL lock, **not** the device's hardware READY/DONE status. Do not equate them to configuration LEDs.

## Build on Windows / Gowin IDE

1. `git pull` in `C:\GitHub\Sipeed-FPGA`.
2. Open `pikosol_term_dvi.gprj` in Gowin IDE v1.9.9 or compatible.
3. Set **Use SSPI as regular IO** and **Use CPU as regular IO** if the target configuration demands them.
4. Run Synthesis, Place & Route and Bitstream Generation. Verify reports, especially timing. No build is asserted here.
5. Only after building, use Programmer `--device GW5A-25A --cable-index 1 --operation_index 2 --fsFile <generated.fs>`.
6. Connect UART terminal to the validated FPGA USB-UART COM port on 115200 8N1, send `HELLO` or `PiKoSoL`; expect text on the DVI monitor, not on UART TX.

## Provenance

- HDMI transmitter, Gowin PLL: [thisiseth/tang-primer-25k-spi-io](https://github.com/thisiseth/tang-primer-25k-spi-io), commit `cce99075f06d0946c8a70c221118df2c4b57fe2a`; original HDMI modules credit [Sameer Puri hdl-util/hdmi](https://github.com/hdl-util/hdmi), MIT/Apache-2.0. Keep source headers intact.
- UART RX: vendor-derived Sipeed `UART/simple_uart/src/uart_rx.v`, earlier mirrored under `ip/uart/sipeed-primer25k/`; original UART Hello had BOARD PASS.
- Font ROM: existing PiKoSoL `Tang-Nano-9K/01-PicoRV32/lab04/rtl/lab04_font_8x12.hex` (2048 bytes, 128*16 slots), copied under new project.
- This integration glue: PiKoSoL programme.

## Known risks

1. PLL HDMI 720 donor is configured for 50 MHz source and 75/375 MHz pixel clocks; verify PLL lock, timing and monitor acceptance.
2. Synthesis of the dual-address read/write text RAM and font ROM depends on Gowin BRAM inference. A populated initialization in RTL does not prove the resulting bitstream has valid BRAM content.
3. HDMI source uses SystemVerilog `logic`, `parameter int` and unpacked audio ports. Use project toolchain that supports SV, and examine parser output.
4. `hdmi` uses a parameterized 720p display; DVI-only mode does not require audio.
5. Mixed board-level PMOD pin options may require selecting the correct physical header; pin list is copied from a specific reference implementation and **not separately verified on our hardware**.

## 2026-11-14: first Gowin parser failure and remedy

User's initial synthesis log: `EX3863`, `EX3444` on SystemVerilog `logic`/`int`/`always_ff`, plus `EX3998` on `audio_silence`. The project was treated as **Verilog 2001**, which is the default in GowinSynthesis. This is not yet an HDMI or BRAM hardware result. Before changing vendor RTL, set **Project -> Configuration -> Synthesize -> General -> Verilog Language = System Verilog 2017**. Alternately, run `Synthesize_SV2017.ps1`; this invokes `gw_sh.exe` with `set_option -verilog_std sysv2017` as documented in official Gowin SUG1220. Script only synthesizes and does not touch FPGA.

SystemVerilog mode is necessary; it has **not** been proved sufficient: review any remaining `EX3998` and implementation errors in subsequent log. No BUILD PASS claim until reports actually pass.
