# LAB-04: isolated Gowin build, no LAB-03 reassembly or source modification.
# Outputs ONLY to ignored lab04/build/<mode>_<timestamp>_<guid>/.
param(
    [ValidateSet('Smoke','CPU')][string]$Mode = 'Smoke',
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $lab
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
$vendor = Join-Path $root 'vendor\picotiny_ref'
if (-not (Test-Path -LiteralPath $gw -PathType Leaf)) {
    throw "Gowin CLI not found: $gw"
}
$mustVendor = @('SOURCE_PIN.txt','hw\hdmi\svo_hdmi_top.v',
    'hw\hdmi\svo_defines.vh','hw\hdmi\svo_tmds.v',
    'gowin_ip\gowin_rpll\gowin_rpll.v','gowin_ip\gowin_clkdiv\gowin_clkdiv.v')
foreach ($name in $mustVendor) {
    if (-not (Test-Path -LiteralPath (Join-Path $vendor $name) -PathType Leaf)) {
        throw "Missing pinned Sipeed video source $name; run tools/fetch_picotiny.ps1 first"
    }
}
$pin = 'c3b795799f23de91982be52db4273a8eea100cdb'
$pinPath = Join-Path $vendor 'SOURCE_PIN.txt'
if (-not ((Get-Content -LiteralPath $pinPath -Raw).Contains($pin))) { throw 'Upstream PicoTiny SHA provenance mismatch' }
$manifestPath = Join-Path $vendor 'SOURCE_SHA256.txt'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) { throw 'Missing upstream source SHA-256 manifest' }
$vendorLines = @(Get-Content -LiteralPath $manifestPath)
if ($vendorLines.Count -ne 11) { throw 'Expected 11 pinned third-party HDL files' }
foreach ($line in $vendorLines) {
    if ($line -cnotmatch '^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$') { throw "Bad pinned vendor SHA line: $line" }
    $expected = $Matches[1]
    $path = $Matches[2]
    if ($path.Contains('..')) { throw 'Unexpected parent reference in vendor checksum path' }
    $file = Join-Path $vendor ($path.Replace('/','\'))
    if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { throw "Pinned vendor file missing: $path" }
    $actual = (Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actual -cne $expected) { throw "Pinned vendor checksum mismatch: $path" }
}
Write-Host "LAB04_UPSTREAM_VIDEO_SHA256_PASS: $($vendorLines.Count) files at $pin"
if ($Mode -eq 'CPU') {
    & python (Join-Path $lab 'tools\build_rom.py') --check
    if ($LASTEXITCODE -ne 0) { throw 'LAB04 ROM not reproducible; refusing CPU build.' }
    $cpu = Join-Path $root 'vendor\picorv32\picorv32.v'
    if (-not (Test-Path -LiteralPath $cpu -PathType Leaf)) {
        throw "Pinned PicoRV32 not present: $cpu; run original 01-PicoRV32/tools/fetch_picorv32.ps1"
    }
}
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$folder = "{0}_{1}_{2}" -f $Mode.ToLowerInvariant(),$stamp,[guid]::NewGuid().ToString('N').Substring(0,6)
$job = Join-Path $lab ("build\" + $folder)
$work = Join-Path $job 'work'
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach ($dir in @((Join-Path $work 'lab04\rtl'), (Join-Path $work 'lab04\constraints'),
    (Join-Path $work 'rtl'), (Join-Path $work 'vendor\picotiny_ref'),
    (Join-Path $work 'vendor\picorv32'))) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
Copy-Item -Path (Join-Path $lab 'rtl\*.v') -Destination (Join-Path $work 'lab04\rtl')
# GowinSynthesis resolves readmemh from the build work directory; Icarus
# resolves it from the test process cwd. Stage font into both expected places.
$font = Join-Path $lab 'rtl\lab04_font_8x12.hex'
if ($Mode -eq 'CPU') {
    if (-not (Test-Path -LiteralPath $font -PathType Leaf)) { throw "Font ROM missing: $font" }
    Copy-Item -LiteralPath $font -Destination (Join-Path $work 'lab04_font_8x12.hex')
    $rom = Join-Path $lab 'firmware\lab04_boot.hex'
    if (-not (Test-Path -LiteralPath $rom -PathType Leaf)) { throw "ROM HEX missing: $rom" }
    Copy-Item -LiteralPath $rom -Destination (Join-Path $work 'lab04_boot.hex')
    Copy-Item -LiteralPath $rom -Destination (Join-Path $work 'lab04\rtl\lab04_boot.hex')
    Copy-Item -LiteralPath $font -Destination (Join-Path $work 'lab04\rtl\lab04_font_8x12.hex')
}
Copy-Item -Path (Join-Path $lab 'constraints\*') -Destination (Join-Path $work 'lab04\constraints')
Copy-Item -LiteralPath (Join-Path $vendor 'hw') -Destination (Join-Path $work 'vendor\picotiny_ref') -Recurse
Copy-Item -LiteralPath (Join-Path $vendor 'gowin_ip') -Destination (Join-Path $work 'vendor\picotiny_ref') -Recurse
# Gowin Verilog include search varies by release; also place the unmodified
# upstream header in the current compilation directory.
Copy-Item -LiteralPath (Join-Path $vendor 'hw\hdmi\svo_defines.vh') -Destination (Join-Path $work 'svo_defines.vh')
if ($Mode -eq 'CPU') {
    Copy-Item -LiteralPath (Join-Path $root 'rtl\uart_tx_8n1.v') -Destination (Join-Path $work 'rtl')
    Copy-Item -LiteralPath (Join-Path $root 'rtl\uart_rx_8n1.v') -Destination (Join-Path $work 'rtl')
    Copy-Item -LiteralPath $cpu -Destination (Join-Path $work 'vendor\picorv32')
}
$buildTcl = if ($Mode -eq 'CPU') { 'gowin_lab04_cpu.tcl' } else { 'gowin_lab04_smoke.tcl' }
Copy-Item -LiteralPath (Join-Path $lab "build_scripts\$buildTcl") -Destination (Join-Path $work $buildTcl)
$inputs = @(Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName | ForEach-Object {
    [PSCustomObject]@{
        Path = $_.FullName.Substring($work.Length + 1)
        SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
})
$inputs | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -Encoding utf8 -NoTypeInformation
Write-Host "LAB04_ISOLATED_BUILD_DIR: $work"
Write-Host "LAB04_BUILD_MODE: $Mode"
$goStatus = 0
Push-Location $work
try {
    & $gw $buildTcl *> (Join-Path $job 'gowin_cli.log')
    $goStatus = $LASTEXITCODE
} finally { Pop-Location }
if ($goStatus -ne 0) {
    throw "Gowin returned $goStatus; inspect $job\gowin_cli.log (no FPGA was programmed)"
}
$outputName = if ($Mode -eq 'CPU') { 'picorv32_lab04_hdmi_nano9k' } else { 'lab04_hdmi_smoke_nano9k' }
$bitstreams = @(Get-ChildItem -LiteralPath $work -Recurse -Filter ($outputName + '.fs') -File)
if ($bitstreams.Count -ne 1) {
    throw "Gowin finished but expected .fs count=$($bitstreams.Count) instead of 1; inspect $job\gowin_cli.log"
}
$artifact = Join-Path $job ($outputName + '.fs')
Copy-Item -LiteralPath $bitstreams[0].FullName -Destination $artifact
$hash = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash
Write-Host "LAB04_BITSTREAM_CANDIDATE: $artifact"
Write-Host "LAB04_BITSTREAM_SHA256: $hash"
Write-Host 'LAB04_GOWIN_BUILD_OUTPUT_READY: synthesis flow completed; PnR/STA/board NOT independently audited.'
Write-Host 'Inspect Gowin synthesis, place-and-route, and timing reports before SRAM programming.'
