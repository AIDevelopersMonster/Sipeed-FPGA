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
