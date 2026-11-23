#requires -Version 7.0
# LAB-00: explicit opt-in for VOLATILE FPGA SRAM only. Never programs Flash.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Bitstream,
    [switch]$Program,
    [string]$ExpectedSha256 = '',
    [int]$CableIndex = 1,
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference = 'Stop'
$fs = (Resolve-Path -LiteralPath $Bitstream -ErrorAction Stop).Path
if ((Split-Path $fs -Leaf) -cne 'tang_nano9k_lab00_led.fs') {
    throw 'Expected LAB-00 bitstream tang_nano9k_lab00_led.fs'
}
$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($ExpectedSha256 -ne '' -and $hash -cne $ExpectedSha256.ToUpperInvariant()) {
    throw "SHA256 mismatch. Actual $hash"
}
$prog = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
if (-not (Test-Path -LiteralPath $prog -PathType Leaf)) {
    throw "Gowin Programmer not found: $prog"
}
Write-Host "LAB00_BITSTREAM=$fs"
Write-Host "LAB00_SHA256=$hash"
Write-Host 'TARGET=GW1NR-9C; OPERATION=2 (SRAM ONLY, VOLATILE)'
if (-not $Program) {
    Write-Host 'DRY_RUN: no programming performed. Add -Program only after reviewing PnR/STA.'
    return
}
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index $CableIndex
if ($LASTEXITCODE -ne 0) { throw "SRAM programming failed (exit $LASTEXITCODE)" }
Write-Host 'LAB00_SRAM_PROGRAM_COMMAND_PASS: check the six physical LEDs and reset; BOARD PASS NOT AUTOMATIC'
