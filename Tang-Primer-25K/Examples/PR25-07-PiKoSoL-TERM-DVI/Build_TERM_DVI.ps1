# PR25-07: Build in Gowin without programming FPGA or external Flash.
# Run from PowerShell: .\Build_TERM_DVI.ps1
param([string] $GowinShell = "C:\\Gowin\\Gowin_V1.9.9Beta-4_Education\\IDE\\bin\\gw_sh.exe")
$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
if (!(Test-Path -LiteralPath $GowinShell)) {
    throw "Missing Gowin Tcl shell: $GowinShell"
}
$fs = Join-Path $root "impl\\pnr\\pikosol_term_dvi.fs"
$started = Get-Date
Push-Location -LiteralPath $root
try {
    & $GowinShell "Build_TERM_DVI.tcl"
    if ($LASTEXITCODE -ne 0) { throw "Gowin build ended with exit $LASTEXITCODE" }
    if (!(Test-Path -LiteralPath $fs)) { throw "Bitstream was not generated: $fs" }
    $item = Get-Item -LiteralPath $fs
    if ($item.LastWriteTime -lt $started.AddSeconds(-5)) {
        throw "Bitstream is older than this build: $fs"
    }
    Write-Host "Bitstream present; inspect PnR/timing reports before programming FPGA"
    $item | Select-Object FullName,Length,LastWriteTime
    Get-FileHash -LiteralPath $fs -Algorithm SHA256
} finally { Pop-Location }
