# EX20-05 stage A standalone testbench. No FPGA/JTAG writes.
[CmdletBinding()]
param(
  [string]$Iverilog = 'iverilog',
  [string]$Vvp = 'vvp'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rtl = Join-Path $root 'rtl\video_wb_overlay.v'
$tb = Join-Path $PSScriptRoot 'tb_video_wb_overlay.v'
$build = Join-Path $PSScriptRoot 'build'
New-Item -ItemType Directory -Path $build -Force | Out-Null
$out = Join-Path $build 'video_overlay_tb.vvp'
& $Iverilog -g2012 -s tb_video_wb_overlay -o $out $rtl $tb
if ($LASTEXITCODE -ne 0) { throw "iverilog build failed: $LASTEXITCODE" }
& $Vvp $out
if ($LASTEXITCODE -ne 0) { throw "vvp simulation failed: $LASTEXITCODE" }
Write-Host 'EX20-05 VIDEO RTL SIM EXIT 0; inspect SIM PASS line above. No hardware writes.'
