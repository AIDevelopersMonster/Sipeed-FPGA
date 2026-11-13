# Tang Primer 25K / PMOD0 (J4): rebuild Sipeed SVO in 800x600 mode.
# Gowin 1.9.9: create_project + add_file + run all in the same gw_sh run.
# Original vendor sources and the FPGA Flash are not modified.
# Optional -Program is SRAM-only (run 2); default is build only.
param([switch]$Program)

$ErrorActionPreference = 'Stop'
$vendor = 'C:\GitHub\TangPrimer-25K-example\hdmi\svo'
$work = 'C:\GitHub\TangPrimer25K_DVI_SVGA_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
if (-not (Test-Path (Join-Path $vendor 'hdmi.gprj'))) {
    throw "Missing vendor project: $vendor"
}
New-Item -ItemType Directory -Path $work -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $vendor 'src') -Destination (Join-Path $work 'src') -Recurse

function Patch-One([string]$path, [string]$old, [string]$new) {
    $txt = [System.IO.File]::ReadAllText($path)
    $matches = [regex]::Matches($txt, [regex]::Escape($old))
    if ($matches.Count -ne 1) {
        throw "Expected one match, found $($matches.Count) in $path"
    }
    [System.IO.File]::WriteAllText($path, $txt.Replace($old, $new),
        [System.Text.UTF8Encoding]::new($false))
}
Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.MDIV_SEL = 17;' 'defparam PLLA_inst.MDIV_SEL = 16;'
Patch-One (Join-Path $work 'src\gowin_pll\gowin_pll.v') 'defparam PLLA_inst.ODIV0_SEL = 1;' 'defparam PLLA_inst.ODIV0_SEL = 4;'
Patch-One (Join-Path $work 'src\svo_hdmi.v') 'parameter SVO_MODE             =   "1920x1080";' 'parameter SVO_MODE             =   "800x600";'

$roots = @('C:\Gowin', 'C:\Program Files\Gowin') | Where-Object { Test-Path $_ }
$gw = Get-Command 'gw_sh.exe' -ErrorAction SilentlyContinue |
      Select-Object -First 1 -ExpandProperty Source
if (-not $gw -and $roots) {
    $gw = Get-ChildItem -Path $roots -Recurse -File -Filter 'gw_sh.exe' -ErrorAction SilentlyContinue |
          Sort-Object LastWriteTime -Descending |
          Select-Object -First 1 -ExpandProperty FullName
}
if (-not $gw) { throw "gw_sh.exe not found. Patched sources remain in $work" }

# No open_project in Gowin 1.9.9.
$rootTcl = $work.Replace('\','/')
$srcTcl = "$rootTcl/src"
$files = @(
    'gowin_clkdiv/gowin_clkdiv.v',
    'gowin_pll/gowin_pll.v',
    'hdmi/svo_enc.v',
    'hdmi/svo_openldi.v',
    'hdmi/svo_pong.v',
    'hdmi/svo_tcard.v',
    'hdmi/svo_term.v',
    'hdmi/svo_tmds.v',
    'hdmi/svo_utils.v',
    'hdmi/svo_vdma.v',
    'svo_hdmi.v',
    'top.v'
)
$lines = @(
    "create_project -name hdmi -dir {$rootTcl} -pn GW5A-LV25MG121NES -device_version A -force"
)
foreach ($file in $files) {
    $localFile = Join-Path (Join-Path $work 'src') $file
    if (-not (Test-Path $localFile)) { throw "Missing RTL: $file" }
    $lines += "add_file {$srcTcl/$file}"
}
$lines += "add_file {$srcTcl/hdmi.cst}"
$lines += "add_file {$srcTcl/hdmi.sdc}"
$lines += 'set_option -top_module top'
$lines += "set_option -include_path {$srcTcl;$srcTcl/hdmi}"
$lines += 'run all'
$lines += 'run close'
$tcl = Join-Path $work 'build_legacy.tcl'
$lines | Set-Content -LiteralPath $tcl -Encoding ascii

Write-Host "PROJECT: $work"
Write-Host "TOOL: $gw"
Write-Host 'VIDEO: 800x600 @ 60 Hz, 40 MHz pixel clock / 200 MHz serializer clock'
$logFile = Join-Path $work 'build.log'
Push-Location $work
try {
    & $gw $tcl 2>&1 | Tee-Object -FilePath $logFile
    $status = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($status -ne 0) { throw "Gowin failed ($status): $logFile" }
$fs = Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'hdmi.fs' |
      Select-Object -First 1 -ExpandProperty FullName
if (-not $fs) { throw "No hdmi.fs generated; inspect $logFile" }
Write-Host "BITSTREAM: $fs"
Get-FileHash -Algorithm SHA256 -LiteralPath $fs | Format-List

if ($Program) {
    $cli = Get-Command 'programmer_cli.exe' -ErrorAction SilentlyContinue |
           Select-Object -First 1 -ExpandProperty Source
    if (-not $cli -and $roots) {
        $cli = Get-ChildItem -Path $roots -Recurse -File -Filter 'programmer_cli.exe' -ErrorAction SilentlyContinue |
               Sort-Object LastWriteTime -Descending |
               Select-Object -First 1 -ExpandProperty FullName
    }
    if (-not $cli) { throw 'No programmer_cli.exe found; FPGA not programmed' }
    & $cli --device GW5A-25A --run 2 --fsFile $fs --cable-index 1
    if ($LASTEXITCODE -ne 0) { throw "SRAM Program failed: $LASTEXITCODE" }
    Write-Host 'SRAM upload complete. Visual PMOD0/HDMI output not yet verified.'
}
