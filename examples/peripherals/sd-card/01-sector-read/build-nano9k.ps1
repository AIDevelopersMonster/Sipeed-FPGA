# Reuses validated independent LAB-05 SD probe. Build only; no programming.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$builder=Join-Path $repo '01-PicoRV32\lab05\tools\build_lab05_probe.ps1'
if(-not (Test-Path -LiteralPath $builder -PathType Leaf)) { throw "SD probe builder absent: $builder" }
& $builder -GowinRoot $GowinRoot
if(-not $?) { throw 'SD standalone Gowin build failed' }
