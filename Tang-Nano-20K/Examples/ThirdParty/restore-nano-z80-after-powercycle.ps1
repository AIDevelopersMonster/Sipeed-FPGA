# TP20-02: restore previously verified nano-Z80 after Tang Nano 20K power-cycle.
# One command invokes two previously tested local scripts:
#   1. Gowin SRAM-only bitstream programming (NO FLASH)
#   2. BL616 volatile MS5351 clocks (NO -s)
# This script never writes config Flash or SD.
# Windows PowerShell 5.1 / PowerShell 7.
[CmdletBinding()]
param(
    [string]$Port = 'COM25',
    [ValidateSet(0,1,2,3)][int]$CableIndex = 1
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$program = Join-Path $root 'program-nano-z80-gowin.ps1'
$pll = Join-Path $root 'tp20-enable-pll-volatile.ps1'
$fs = Join-Path $root 'downloads\nano-z80.fs'
foreach ($required in @($program,$pll,$fs)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Required file not found: $required"
    }
}
Write-Host '== TP20-02: restore nano-Z80 after power-cycle =='
Write-Host 'External hardware: USB-C/UART + HDMI + optional microSD only.'
Write-Host 'FPGA config Flash: NOT WRITTEN. SD: NOT WRITTEN.'
Write-Warning 'Close MobaXterm or other applications using COM25 before starting.'
Write-Host 'STEP 1/2: program nano-Z80 into volatile FPGA SRAM with Gowin.'
Write-Host 'Enter SRAM when requested by the verified Gowin script.'
& $program -Program -CableIndex $CableIndex
if (-not $?) { throw 'STEP 1 failed: Gowin SRAM programming did not finish successfully.' }
Write-Host 'STEP 1/2 COMPLETE: Gowin SRAM loading command returned.'
Write-Host ''
Write-Host "STEP 2/2: enable MS5351 O0=25.175MHz and O1=12MHz through $Port."
Write-Host 'Enter CLOCKS when requested. No persistent PLL save (-s).'
& $pll -Port $Port -Apply
if (-not $?) { throw 'STEP 2 failed: MS5351 verification did not finish successfully.' }
Write-Host 'STEP 2/2 COMPLETE: MS5351 verification returned.'
Write-Host ''
Write-Host 'TP20 RESTORE COMMANDS COMPLETED; ROM and SD BOARD PASS NOT YET RETESTED.'
Write-Host 'Now press/release S2 on the Tang Nano 20K (verified operator RESET button).'
Write-Host "Open MobaXterm: $Port, 115200 baud, 8N1, flow control NONE."
Write-Host "Expected: nano-Z80 monitor v0.3 ... Ready"
Write-Host 'If a prepared CP/Mish microSD is inserted, test SD status before L.'
Write-Host 'Do not unplug power; volatile MS5351 outputs may be lost.'
