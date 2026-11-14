# Second independent HDMI+audio implementation for Tang Primer 25K

## Origin / scope

- Original repository: [thisiseth/tang-primer-25k-spi-io](https://github.com/thisiseth/tang-primer-25k-spi-io)
- Pinned upstream commit: `cce99075f06d0946c8a70c221118df2c4b57fe2a`, upstream `main` at inspection on 2026-11-14.
- Upstream author describes **1280x720@60 HDMI with 16-bit, 48-kHz stereo audio**, and demonstrates Doom / Quake using ESP32-S3 over SPI and on-chip BRAM. This is a **documented third-party demo, not a locally reproduced hardware BOARD PASS**.
- No external SDRAM required for the original FPGA HDMI/audio function. The **original full application still requires an ESP32-S3 to supply video/audio over SPI**, and includes a USB host/softcore not present in the source slice.
- `vendor/` contains **22 byte-identical pinned Git blobs**: HDMI/audio modules, original PLL+audio FIFO IP, original top, pins, timing, project descriptor and its direct SPI/framebuffer dependencies. **Not a standalone compilable complete original**, as the original Gowin project also refers to USB-host modules omitted from this reference slice. For full reproduction use upstream pinned commit.
- Root `vendor/LICENSE` is upstream MIT; individual embedded third-party files retain their own copyright/licensing notices. Upstream README explicitly credits **hdl-util/hdmi by Sameer Puri under MIT / Apache-2.0**. Do not assume every upstream dependency is relicensed MIT; inspect individual headers.
- PR25-08 / PR25-09 / PR25-10 and PiKoSoL have NOT been modified.

## Why this example is useful

In upstream `src/top.sv`:

```systemverilog
`define GW_IDE
hdmi #(
    .VIDEO_ID_CODE(4),
    .DVI_OUTPUT(0),    // true HDMI + audio
    .VIDEO_REFRESH_RATE(60.0),
    .AUDIO_RATE(48000)
) hdmi (
    .clk_pixel_x5(clk_pixel_x5),
    .clk_pixel(clk_pixel),
    .clk_audio(clk_audio),
    .audio_sample_word(audio_sample_word),
    // ...
);
```

The original project selects a 720p PLL `gowin_pll_hdmi_720` with **~74.25 MHz pixel, ~375 MHz x5**, and pixel-to-audio-divider `PIXEL_TO_AUDIO_DIV = 1562`. Audio comes from `gowin_fifo_audio` (BRAM), not from on-chip Atari audio synthesis. The FPGA produces **two-channel, 16-bit PCM** via 32-bit stereo sample words:

```systemverilog
// From vendor/src/top.sv
always_ff @(posedge clk_audio)
    audio_sample_word <= '{audio_fifo_out[31:16], audio_fifo_out[15:0]};
```

It uses the *same* basic hdl-util HDMI packetizer lineage as A2600Nano, but a **different fork with `DVI_OUTPUT=0` explicitly**, fixed 720p CEA timings, and different audio source/timing. This is a useful independent control path. Do **not** mix the donor's `hdmi.sv` with the Atari-fork `packet_picker.sv` without reviewing API and packet/timing assumptions.

Note: the upstream CST defines single-ended `hdmi_tx_tmds[0:2]` and clock P pins, while our confirmed working A2600Nano-derived solution used `ELVDS_OBUF` with P/N pairs. For an independent minimal FPGA tone demo, **preserve the known-working differential output configuration from PR25-08**, adapting only the donor HDL and audio PCM connection as a separate controlled build. This combination remains a **candidate**, not a tested image. Original donor itself is documented as functioning with Sipeed PMOD DVI.

## What the user's actual tests tell us

- A2600Nano unchanged `.fs`: **video+audio BOARD PASS**, operator confirmation.
- PR25-08: **video BOARD PASS, audio NOT audible**.
- PR25-09: **video and green/red test-tone marker working; audio NOT audible**.
- PR25-10: **all D0-D4 scheduler flags GREEN** (Data Island slots, PCM sample buffer ready, Audio Sample Packet scheduled, ACR packet scheduled, Audio InfoFrame scheduled), with additional test-tone marker flashing; **still no audible audio**.

**Conclusion:** our generator and internal *packet scheduling* have evidence of activity; it is not justified to increase tone amplitude or add more scheduler flags. **Green flags do NOT prove valid encoded HDMI data islands, IEC 60958 channel status, CTS/N, or sink recognition.**

## Preferred next engineering route

1. Freeze PR25-08 as **VIDEO GOLDEN** and original A2600Nano v2.5 firmware as **AUDIO+VIDEO GOLDEN**. Stop ad hoc changes to these.
2. Use donor's complete **HDMI audio IP family** (`src/hdmi/*.sv`), `DVI_OUTPUT=0`, 720p timing/clock settings and original FIFO connection as the new baseline; do NOT mix implementations by choosing arbitrary files.
3. Create a **small isolated stereo PCM tone source at the input of donor's existing audio FIFO**, without ESP32-S3, framebuffer, or USB. This would eliminate the need for new external peripherals; source code for this standalone wrapper is not yet implemented or verified.
4. Keep known-good TP25K PMOD differential electrical layer and only then run Gowin build/STA and FPGA SRAM test.
5. The resulting FPGA image can be designated **audio+video IP BOARD PASS** only after the operator hears sound and sees image, otherwise label the actual failure precisely.

## Licenses and delivery status

**SOURCE SNAPSHOT PASS** — original source blob SHA-1s match upstream. **Standalone Gowin BUILD: NOT RUN. Standalone hardware: NOT TESTED**. Full original application hardware demonstration is attested by the original README and YouTube links; it has **not** been independently reproduced here.

See: [original donor RTL](https://github.com/thisiseth/tang-primer-25k-spi-io/tree/cce99075f06d0946c8a70c221118df2c4b57fe2a/src/fpga/spi_io_bridge/src).
