# PR25-10: only volatile FPGA SRAM. External Flash is not touched.
param(
    [int]$CableIndex = 1,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
$ErrorActionPreference = 'Stop'
$fs = Join-Path $PSScriptRoot 'impl\pnr\pr25_hdmi_audio_packet_probe.fs'
if (!(Test-Path -LiteralPath $Programmer)) { throw "Missing Programmer: $Programmer" }
if (!(Test-Path -LiteralPath $fs)) { throw "Build required first; missing: $fs" }
if ((Get-Item $fs).Length -lt 100000) { throw 'Implausibly small bitstream' }
Get-FileHash -LiteralPath $fs -Algorithm SHA256
Write-Host "GW5A-25A, cable ${CableIndex}: SRAM PROGRAM (--run 2)"
& $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
$exit = $LASTEXITCODE
Write-Host "SRAM PROGRAM EXIT: $exit"
if ($exit -ne 0) { throw 'SRAM program failed' }
Write-Host 'Observe 5 HDMI packet status flags, tone generator marker and audible audio. Report which of D0-D4 are green.'
