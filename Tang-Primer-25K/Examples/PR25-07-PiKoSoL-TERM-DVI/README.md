# PiKoSoL 25K TERM-DVI v0.1 — engineering candidate

**Target:** Tang Primer 25K + Dock, GW5A-LV25MG121NES. `UART RX -> text BRAM -> 720p DVI`, **no processor and no external SDRAM**.

## Status (2026-11-14)

- Source integrated with vendor-derived PLL, DVI encoder and PiKoSoL font.
- **SYNTHESIS PASS 2026-11-14; PnR and BITSTREAM NOT YET PASS; NOT PROGRAMMED or BOARD-VERIFIED.** The source is an engineering candidate, not a tested firmware.
- On-board HDMI output is *not* used; connect Sipeed DVI PMOD to the pins mapped in `pins.cst`. Physical connector alignment still must be checked. Previous HDMI test had no image.
- Configuration Flash is not required. Use only `SRAM Program` for the first run.

## Features in this initial candidate

- Video: 1280x720 @ 60 DVI signal; centered native 640x480 character raster, 80x30 characters and 8x16 font.
- UART: RX 115200 8N1, FPGA B3; incoming printable ASCII writes to screen; CR, LF and backspace supported. The TX line C3 remains idle in this version.
- Initial top line: `PiKoSoL 25K TERM-DVI`.
- No scrolling (wraps from last line to line 1); no ANSI escape sequences, command parser, GFX or fonts beyond ASCII 0-127.
- Pixel pipeline latency can shift origin by ~2 pixel clocks; accepted only for first bring-up.
- The configuration READY (E8) and DONE (D7) pins remain dedicated and are not driven by PiKoSoL.

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

## 2026-11-14: EX3934 initialization loop limit

The next synthesis log reached `Extracting RAM` for both memories and stopped at `EX3934: Loop count limit of 2000 exceeded` (original RTL line 51). Fixed by replacing the 2400-iteration RTL `for` with `$readmemh("rtl/text_init.hex", text_ram)`; the new 2400-line, 8-bit text image contains spaces and initial banner `PiKoSoL 25K TERM-DVI`. The font initialization still uses the PiKoSoL `font_8x16.hex`. Both hex files are listed as `file.other` in the Gowin project. **Needs a new synthesis run; this is not yet a BUILD PASS.**

## 2026-11-14: Gowin TMDS serializer selection (`EX2000` / `EX1999`)

Subsequent synthesis log confirms text/ROM extraction, HDMI encoder, PLL and UART RX compilation. It then failed in `vendor/hdmi/serializer.sv` at lines 281/283 because the *generic* serializer branch drove the same `tmds[2]` from both clock edges. The donor's `src/top.sv` declares `GW_IDE`, selecting the **Gowin `OSER10` branch** of `serializer.sv`, but the PiKoSoL project didn't set that macro. The local vendored `serializer.sv` now explicitly defines `GW_IDE` at its top so the correct Gowin primitive branch is selected without reliance on cross-source-file macro propagation. This is a **documented integration patch to the vendored copy**, not an upstream source fix. Upstream preserved below the added header. Result is **not yet re-synthesized or board-verified**.

## 2026-11-14: PnR PR2017 on special pins (fixed in source)

Latest Gowin log: GowinSynthesis successfully generated `pikosol_term_dvi.vg` and its report (SYNTHESIS PASS). PnR then failed with `PR2017` / `PR2028`: `clk_50m` E2 is a CPU/SSPI dual-purpose pin, `led_ready` E8 is dedicated READY, and `led_done` D7 is dedicated DONE. Removed both unnecessary LED output ports and corresponding constraints: E8/D7 stay reserved for the FPGA configuration status. Clock E2 stays because it is the actual board 50 MHz oscillator; select **Use CPU as regular IO** in `Project > Configuration > Place & Route > Dual-Purpose Pin`. The companion `Build_TERM_DVI.tcl` enables the setting with `set_option -use_cpu_as_gpio 1`, keeps SSPI GPIO enabled, and requests BRAM initialization in the bitstream. `Build_TERM_DVI.ps1` calls that script. No RTL changes to HDMI or PLL. New PnR attempt and timing analysis still required; no FPGA/hardware pass claimed.
