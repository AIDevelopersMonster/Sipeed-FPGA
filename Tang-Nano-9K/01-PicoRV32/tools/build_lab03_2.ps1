# Separate Gowin route for LAB-03.2. Only compiles; never programs flash or SRAM.
param([string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path $gw)) { throw "Gowin CLI not found: $gw" }
if (-not (Test-Path (Join-Path $base 'vendor\picorv32\picorv32.v'))) {
    throw 'Pinned PicoRV32 missing; first run tools/fetch_picorv32.ps1.'
}
Push-Location $base
try {
    & python tools/assemble_lab03.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 ROM assembly failed' }
    & $gw 'gowin_lab03_2_build.tcl'
    if ($LASTEXITCODE -ne 0) { throw "Gowin build failed: $LASTEXITCODE" }
    Write-Host 'Gowin finished. Inspect utilization/PnR/STA before setting PNR_PASS or programming SRAM.'
    Get-ChildItem -Recurse -Filter 'picorv32_lab03_nano9k.fs' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName
} finally { Pop-Location }
