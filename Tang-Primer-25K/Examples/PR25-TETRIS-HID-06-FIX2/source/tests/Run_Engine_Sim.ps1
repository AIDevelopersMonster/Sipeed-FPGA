#Requires -Version 7.0
# Optional RTL-only test. Requires Icarus Verilog from MSYS2 or PATH.
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$root = Split-Path -Parent $PSScriptRoot
$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue)?.Source
$vvp = (Get-Command vvp -ErrorAction SilentlyContinue)?.Source
if (!$iverilog) { $iverilog='C:\msys64\ucrt64\bin\iverilog.exe' }
if (!$vvp) { $vvp='C:\msys64\ucrt64\bin\vvp.exe' }
if (!(Test-Path $iverilog) -or !(Test-Path $vvp)) {
    throw 'Icarus Verilog not found. Install iverilog/vvp or adjust MSYS2 path.'
}
$build = Join-Path $env:TEMP 'PR25_TETRIS_HID06_SIM'
New-Item -ItemType Directory -Force $build | Out-Null
$out = Join-Path $build 'tetris_engine_tb.vvp'
& $iverilog -g2012 -s tb_tetris_engine -o $out (Join-Path $root 'tetris_engine.sv') (Join-Path $PSScriptRoot 'tb_tetris_engine.sv')
if ($LASTEXITCODE -ne 0) { throw 'RTL compile FAIL' }
& $vvp $out
if ($LASTEXITCODE -ne 0) { throw 'RTL simulation FAIL' }
Write-Host 'RTL SIM PASS (engine only, not proof of USB/Gowin/board)'
