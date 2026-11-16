# PR25 HDMI color bars — Tang Primer 25K

**Hardware result (operator, 2026-11-17): VIDEO BOARD PASS / HDMI AUDIO FAIL.**

This directory preserves the **actual FIX1 source configuration** tested on Sipeed Tang Primer 25K + Dock with a Sipeed DVI PMOD. It is not a completed HDMI-audio implementation and not a release.

## Verified observations

- Gowin build and volatile SRAM programming were completed on the user's Windows host.
- **Visible HDMI picture:** four broad vertical colour bars (red, green, blue, white) on the monitor. **VIDEO BOARD PASS.**
- **HDMI sound:** expected left ~500 Hz and right ~750 Hz tones were not heard. **HDMI AUDIO FAIL.**
- Full HDMI Audio has worked previously on the same board with **A2600Nano Golden**. That success does **not** establish sound functionality of the present experiment.
- No external SDRAM, BL616 firmware changes, ESP32-S3, USB Host or SD card are needed for this test.

## Board / pins

Target: `GW5A-LV25MG121NC1/I0` / GW5A-25A.
50 MHz clock: E2.
Use the **same physical DVI PMOD socket** as the known-working A2600Nano Golden; do not relocate the module based on other PMOD pin tables.

| HDMI signal | Positive / negative GW5A pins |
|---|---|
| TMDS clock | H5 / J5 |
| TMDS data 0 | H8 / H7 |
| TMDS data 1 | G7 / G8 |
| TMDS data 2 | F5 / G5 |

FIX1 adds `set_option -use_cpu_as_gpio 1` in generated Gowin TCL to unlock the dedicated E2/CPU pin. The uncorrected build failed at Place & Route with PR2017.

## Source archive contents

- `pr25_hdmi_audio_top.sv`: actual colour-bar+audio-test HDMI wrapper.
- `pr25_av_content.sv`: verified colour pattern and candidate left/right PCM signal generator.
- `pr25_serializer_gowin.sv`: Gowin-specific 3-lane OSER10 adapter.
- `pr25_hdmi_audio.cst`, `pr25_hdmi_audio.sdc`: FPGA pin and timing constraints.
- `tb_pr25_av_content.sv`: limited simulation test of pixel and PCM generators.
- `Build_PR25_HDMI_AUDIO_BRAM.ps1`: original FIX1 reproduction helper, producing temporary build outputs only.
- `LICENSE`: license of locally authored files and third-party attribution.

The PowerShell helper gets HDMI/PLL dependencies at the immutable upstream commit:

- https://github.com/thisiseth/tang-primer-25k-spi-io — `cce99075f06d0946c8a70c221118df2c4b57fe2a`
- HDMI IP originally from https://github.com/hdl-util/hdmi (MIT / Apache-2.0).

No third-party source files are copied here. The test package depends on the upstream HDL and Gowin PLL for rebuilding.

## Rebuild / safety

On Windows PowerShell 7 with Git, Icarus and Gowin installed, from this directory:

```powershell
./Build_PR25_HDMI_AUDIO_BRAM.ps1 -SimOnly
./Build_PR25_HDMI_AUDIO_BRAM.ps1
```

The optional `-ProgramSRAM` runs a **new rebuild** and requires a JTAG model check plus an explicit `SRAM` confirmation; it **never programs Flash**. All generated artefacts are placed under `%TEMP%/PR25_HDMI_AUDIO_BRAM_01`, not in the Git repository.

**Do not label this configuration as HDMI Audio BOARD PASS.** No `.fs`, build logs, invalid variants or GitHub releases belong in this directory. Future audio work should use a separate unverified experiment until physically tested.
