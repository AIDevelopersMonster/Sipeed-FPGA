#requires -Version 7.0
# KonSol RS-004: Icarus Verilog self-check. Does not program the FPGA.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
foreach ($cmd in @('iverilog','vvp')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Missing $cmd. RS004_SIM_NOT_RUN; install Icarus Verilog."
    }
}
$out = Join-Path $PSScriptRoot 'build\tb'
New-Item -ItemType Directory -Force -Path $out | Out-Null
$exe = Join-Path $out 'kblocks_tb.out'
& iverilog -g2012 -Wall -s tb_kblocks_rgb_core -o $exe `
    (Join-Path $PSScriptRoot 'rtl\kblocks_rgb_core.v') `
    (Join-Path $PSScriptRoot 'tests\tb_kblocks_rgb_core.v')
if ($LASTEXITCODE -ne 0) { throw 'RS004_IVERILOG_FAIL' }
& vvp $exe
if ($LASTEXITCODE -ne 0) { throw 'RS004_TB_FAIL' }
Write-Host 'RS004_TB_EXIT_0' -ForegroundColor Green
