#Requires -Version 7.0
# PiKoSoL Console02 - program only volatile FPGA SRAM.
# Does not write FPGA configuration Flash.
[CmdletBinding()]
param(
    [switch]$Built,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe',
    [int]$CableIndex = 1
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = '8E79A763F17D24BB31700A20459CB26ECB11007513C994A95D26C314AD5A88E0'
if ($Built) {
    $fs = Join-Path $env:TEMP 'PR25_PIKOSOL_CONSOLE_02\impl\pnr\pr25_pikosol_console02.fs'
} else {
    $fs = Join-Path $PSScriptRoot 'firmware\pr25_pikosol_console02.fs'
}
if (!(Test-Path -LiteralPath $Programmer -PathType Leaf)) { throw "Gowin Programmer missing: $Programmer" }
if (!(Test-Path -LiteralPath $fs -PathType Leaf)) { throw "Firmware missing: $fs" }

$actual = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($actual -ne $expected) {
    throw "SHA256 mismatch. Expected $expected, got $actual. Refusing to program."
}

Write-Host "PiKoSoL Console02 firmware SHA256 PASS: $actual"
Write-Host 'FPGA programming: VOLATILE SRAM ONLY (--run 2). No Flash write.'
& $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
if ($LASTEXITCODE -ne 0) { throw "FPGA SRAM programming failed: exit=$LASTEXITCODE" }
Write-Host 'FPGA SRAM PROGRAM CLI PASS (visual/keyboard BOARD check still required)'
