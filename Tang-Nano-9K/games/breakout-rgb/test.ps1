#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
foreach($cmd in @('iverilog','vvp')) {
  if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) { throw "Missing $cmd; simulation NOT RUN." }
}
$target = Join-Path $PSScriptRoot 'build/tb'
New-Item -ItemType Directory -Force -Path $target | Out-Null
$exe = Join-Path $target 'breakout_tb.out'
$core = Join-Path $PSScriptRoot 'rtl/breakout_rgb_core.v'
$tb = Join-Path $PSScriptRoot 'tests/tb_breakout_rgb_core.v'
& iverilog -g2012 -s tb_breakout_rgb_core -o $exe $core $tb
if ($LASTEXITCODE -ne 0) { throw 'RS003_IVERILOG_FAIL' }
& vvp $exe
if ($LASTEXITCODE -ne 0) { throw 'RS003_TB_FAIL' }
Write-Host 'RS003_TB_EXIT_0' -ForegroundColor Green
