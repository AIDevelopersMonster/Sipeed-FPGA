# PR25-PMOD-02 — DVI video test (Tang Primer 25K + Dock)

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
