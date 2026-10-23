# LAB-04: explicit opt-in SRAM programming only; never writes configuration flash.
param(
    [Parameter(Mandatory=$true)][string]$Bitstream,
    [switch]$Program,
    [int]$CableIndex = 1,
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference = 'Stop'
$fs = (Resolve-Path -LiteralPath $Bitstream -ErrorAction Stop).Path
if (-not $fs.EndsWith('.fs',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'Expected .fs Gowin bitstream'
}
$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
$prog = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
if (-not (Test-Path -LiteralPath $prog -PathType Leaf)) { throw "Gowin Programmer not found: $prog" }
Write-Host "BITSTREAM: $fs"
Write-Host "SHA256: $hash"
Write-Host 'OPERATION: GW1NR-9C, operation_index 2, volatile SRAM (not Flash)'
if (-not $Program) {
    Write-Host 'LAB04_SRAM_DRY_RUN_ONLY: no hardware changed. Pass -Program after reviewing report.'
    return
}
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index $CableIndex
if ($LASTEXITCODE -ne 0) { throw "Gowin Programmer failed with exit code $LASTEXITCODE" }
Write-Host 'LAB04_SRAM_PROGRAM_COMMAND_PASS: programmer reported exit 0; visually verify HDMI and LED.'
