# Build the PiKoSoL TERM-DVI synthesis on Windows (no FPGA programming).
# Usage: pwsh -File .\Synthesize_SV2017.ps1
param(
    [string] $GowinShell = "C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe"
)
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (!(Test-Path -LiteralPath $GowinShell)) {
    throw "Cannot find Gowin gw_sh.exe: $GowinShell. Pass -GowinShell <full-path>."
}
Push-Location -LiteralPath $root
try {
    & $GowinShell "Synthesize_SV2017.tcl"
    if ($LASTEXITCODE -ne 0) { throw "Gowin TCL synthesis returned code $LASTEXITCODE" }
    Write-Host "Gowin process finished. Inspect the synthesis report and terminal output for PASS or ERROR."
} finally {
    Pop-Location
}
