# Build for Tang Nano 9K using installed Gowin education IDE, not GUI.
param([string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$Here = Split-Path -Parent $PSScriptRoot
$Gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path $Gw)) { throw "Gowin CLI not found: $Gw. Supply -GowinRoot explicitly." }
if (-not (Test-Path (Join-Path $Here 'vendor\picorv32\picorv32.v'))) {
    throw 'First run tools/fetch_picorv32.ps1 to obtain the pinned ISC-licensed CPU.'
}
Push-Location $Here
try {
  & python tools/assemble.py
  if ($LASTEXITCODE -ne 0) { throw 'Assembly failed.' }
  & $Gw 'gowin_build.tcl'
  if ($LASTEXITCODE -ne 0) { throw "Gowin returned non-zero exit code: $LASTEXITCODE" }
  Write-Host 'Gowin finished. Verify synthesis/PnR reports and timing before programming.'
  Get-ChildItem -Recurse -Filter '*.fs' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
} finally { Pop-Location }
