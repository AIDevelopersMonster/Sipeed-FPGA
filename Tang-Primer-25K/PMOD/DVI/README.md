# PR25-PMOD-02 — DVI video test (Tang Primer 25K + Dock)

## J4 / J5 / J6 to PMOD0 / PMOD1 / PMOD2 mapping

**Canonical mapping for Tang Primer 25K Dock, front side up, USB-A to the left and USB-C to the right:**

| Location | Board PMOD legend | Schematic connector | Sipeed HDMI/SVO RTL | TMDS clock FPGA balls |
|---|---|---|---|---|
| Left | **PMOD0** | **J4** | \`tmds_*_0\` | C11 / C10 |
| Centre | **PMOD1** | **J5** | \`tmds_*_1\` | L5 / K5 |
| Right | **PMOD2** | **J6** | \`tmds_*_2\` | H5 / J5 |

**Important**: J4/J5/J6 are connector designators, **not** PMOD numbers, and FPGA ball \`J5\` is **not** the connector \`J5\`. There is no PMOD3 on this Dock. PMOD0 = J4 is the user's current DVI installation; it does **not** need to be moved merely to match the source's \`_0\` channel.

Cross-check references:

- [Sipeed Dock schematic](https://dl.sipeed.com/fileList/TANG/Primer_25K/02_Schematic/Tang_Primer_25K_Dock_60033_Schematic.pdf) (connector J4/J5/J6 electrical pin map).
- [Sipeed Dock underside photo](https://wiki.sipeed.com/hardware/en/tang/tang-primer-25k/assets/25k_dock_bot.jpg): left header G11/D11/B11/C11 = J4, centre A11/E11/K11/L5 = J5, right F5/G7/H8/H5 = J6.
- [Sipeed official HDMI \`hdmi.cst\`](https://github.com/sipeed/TangPrimer-25K-example/blob/main/hdmi/svo/src/hdmi.cst): \`_0\`, \`_1\`, \`_2\` map to J4, J5, J6 respectively.
- [Sipeed top-side board photo](https://en.wiki.sipeed.com/hardware/en/tang/tang-primer-25k/primer-25k.html), and [pinout study](https://marsee101.blog.fc2.com/blog-entry-6176.html) for physical position.


**Status:** READY TO TEST / NOT YET BOARD PASS.

## Source

- Sipeed upstream: https://github.com/sipeed/TangPrimer-25K-example/tree/main/hdmi/svo
- Gowin project: `hdmi.gprj`; device `GW5A-25A`, part `GW5A-LV25MG121NES`.
- Prebuilt archive: `hdmi.fs.7z` in `hdmi/svo` (verify extraction before programming).
- RTL `src/top.v` instantiates **three** SVO HDMI outputs; `src/hdmi.cst` assigns differential TMDS signals for each PMOD slot.
- Video: test-pattern generator `svo_tcard` (not an OS/game and no audio evidence).
- One known hardware arrangement from MiSTeryNano uses DVI PMOD in **leftmost** slot, with USB-A left and USB-C right: https://github.com/MiSTle-Dev/MiSTeryNano/blob/main/TANG_PRIMER_25K.md . Verify orientation and 2x6 pin alignment before power.

## Hardware procedure

1. Disconnect USB-C power.
2. Remove BTN, DT and LED modules.
3. Mount **DVI in the leftmost PMOD** (USB-A on left, USB-C on right), verifying pin-1 direction, both rows and connector alignment.
4. Connect monitor by HDMI cable to PMOD DVI; select HDMI input on monitor.
5. Reconnect USB-C.
6. Extract `hdmi.fs.7z`; program **SRAM** via known working `programmer_cli.exe` (FT2CH cable index 1).
7. Observe monitor: valid video sync and visible test pattern.

## PowerShell (from local clone)

```powershell
Set-Location 'C:\GitHub\TangPrimer-25K-example\hdmi\svo'
& 'C:\Program Files\7-Zip\7z.exe' x '.\hdmi.fs.7z' -y
$fs = (Resolve-Path '.\hdmi.fs').Path
if (-not $cli -or -not (Test-Path $cli)) {
  $cli = Get-ChildItem 'C:\Gowin' -Recurse -Filter programmer_cli.exe -File -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName
}
if (-not $cli) { throw 'Gowin programmer_cli.exe not found in C:\Gowin' }
& $cli --device GW5A-25A --run 2 --fsFile $fs --cable-index 1
if ($LASTEXITCODE -ne 0) { throw "SRAM programming failed: $LASTEXITCODE" }
```

## Pass criteria

**SRAM Program PASS**: CLI reports SRAM Program 100% and exit code 0.  
**DVI BOARD PASS**: monitor locks to signal and shows a stable picture (operator photograph or explicit observation).  
**No PASS before physical observation.**

If monitor has no image, check PMOD physical seating/pin orientation, monitor HDMI input, and upstream pin constraints. Do not change Flash.

## Upstream source verification (2026-11-14)

Revisited the exact vendor [hdmi/svo](https://github.com/sipeed/TangPrimer-25K-example/tree/main/hdmi/svo) without modifying it. GitHub contains the official `hdmi.fs.7z` (135,811 bytes; decompressed 6,067,601 bytes according to the operator). Operator already obtained `SRAM Program 100%` and `EXIT CODE 0`, **but no picture**.

**Pin mapping cross-checked against the official [Tang Primer 25K Dock schematic](https://dl.sipeed.com/fileList/TANG/Primer_25K/02_Schematic/Tang_Primer_25K_Dock_60033_Schematic.pdf):**

- PMOD connector **J4** ↔ SVO `tmds_*_0`: TMDS clock `C11/C10`, data `B11/B10`, `D11/D10`, `G11/G10`.
- PMOD connector **J5** ↔ `tmds_*_1`: clock `L5/K5`, data `K11/L11`, `E11/E10`, `A11/A10`.
- PMOD connector **J6** ↔ `tmds_*_2`: clock `H5/J5`, data `H8/H7`, `G7/G8`, `F5/G5`.
- `src/top.v` instantiates all three outputs, so the vendor source explicitly drives **all three PMOD sockets**. Do **not** confuse connector J4/J5/J6 with informal PMOD0/PMOD3 labels; use the board schematic and physical silkscreen.
- `src/hdmi.cst` assigns `led` to L6, which is USB_P, **not** a user LED ([upstream issue #12](https://github.com/sipeed/TangPrimer-25K-example/issues/12)). Lack of LED blink does not diagnose HDMI.
- Upstream [issue #11](https://github.com/sipeed/TangPrimer-25K-example/issues/11) includes a tester explicitly reporting the official HDMI demo also does not show video. [Issue #13](https://github.com/sipeed/TangPrimer-25K-example/issues/13) cites bad timing reports.
- Board button S1 on H11 is active-high, internal pulldown is enabled in `hdmi.cst`, and the source uses `~resetn & pll_lock`; polarity is consistent with the [board schematic](https://dl.sipeed.com/fileList/TANG/Primer_25K/02_Schematic/Tang_Primer_25K_Dock_60033_Schematic.pdf) and [issue #11](https://github.com/sipeed/TangPrimer-25K-example/issues/11). Do not assume inversion error.
- **Important correction to an earlier hypothesis:** the SVO source's 1920×1080 mode specifies total pixel timings of `2576×1120`; if the PLL produces 850 MHz then CLKDIV/5 gives 170 MHz pixel clock, equating to approximately **58.9 frames/s**. Comparing 170 MHz with a different CEA 148.5 MHz timing *alone* does not establish an invalid refresh rate. Timing closure / monitor acceptance remain unverified.

### Retest scope

Power off; verify DVI module orientation and alignment in **J4** and HDMI cable/input; power on; repeat vendor binary `programmer_cli.exe --device GW5A-25A --run 2 --fsFile <vendor-hdmi.fs> --cable-index 1`; capture whether monitor shows `No signal`, `Out of range` or a synchronized black screen. This re-test is about physical connectivity and monitor behavior, **not** a new build. If same result, do not repeatedly flash the same bitstream: move to a separately validated video implementation or correct/timing-close SVO as an independent development task.

## Independent prebuilt NESTang port mapping (2026-11-14)

The vendor prebuilt **NESTang** bitstream `nestang-25k/nes.fs.7z` is NOT pin-compatible with PMOD0/J4 for video: its [official `nestang.cst`](https://github.com/sipeed/TangPrimer-25K-example/blob/main/nestang-25k/src/nestang.cst) constrains TMDS output pins to H8/H7, G7/G8, F5/G5, H5/J5: the **right PMOD2/J6** connector, when USB-A is left and USB-C is right. Its SD card signals use G11, C11, D11, B11, i.e. **left PMOD0/J4**. Do not blindly transfer SVO's 3-output mapping to NESTang.

Sipeed `hdmi/svo/hdmi.fs` has **three SVO instances** targeting J4/J5/J6, but repeatedly loads successfully without observed image; firmware is not BOARD PASS. For an independent prebuilt test only:

1. **Power off USB-C**, remove all other PMOD modules, place DVI in **right PMOD2/J6**, ensuring exact 2x6 insertion and power/GND orientation; connect known working HDMI cable and input.
2. `Set-Location C:\GitHub\TangPrimer-25K-example\nestang-25k`; extract `nes.fs.7z` to `nes.fs` using 7-Zip.
3. Program **SRAM only** using `programmer_cli.exe --device GW5A-25A --run 2 --fsFile <path-to-nes.fs> --cable-index 1`.
4. If the monitor shows a signal/palette, **DVI hardware PASS**. If it remains blank, **inconclusive**, because the full NES system needs 40-pin SDRAM and MicroSD; the operator currently lacks SDRAM. No further repeats of SVO binary in this test.

Sources: [vendor NESTang source and prebuilt binary](https://github.com/sipeed/TangPrimer-25K-example/tree/main/nestang-25k), [vendor NESTang README](https://github.com/sipeed/TangPrimer-25K-example/blob/main/nestang-25k/README.md), [Sipeed PMOD DVI documentation](https://wiki.sipeed.com/hardware/en/tang/tang-PMOD/FPGA_PMOD).
