# CPU-free HDMI smoke build; no FPGA programming.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$builder=Join-Path $repo '01-PicoRV32\lab04\tools\build_lab04.ps1'
if(-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw "HDMI builder absent: $builder" }
& $builder -Mode Smoke -GowinRoot $GowinRoot
if(-not $?) { throw 'HDMI smoke build failed' }
