# PiKoSoL 20K: two Icarus tests, never programs FPGA.
[CmdletBinding()]
param([string]$Iverilog='', [string]$Vvp='')
$ErrorActionPreference='Stop'
function Resolve-HdlTool([string]$name,[string]$specified) {
  if ($specified) {
    if(-not(Test-Path -LiteralPath $specified -PathType Leaf)){throw "Missing $name : $specified"}
    return (Resolve-Path -LiteralPath $specified).Path
  }
  $c=Get-Command $name -CommandType Application -ErrorAction SilentlyContinue
  if($c){return $c.Source}
  $known="C:\msys64\ucrt64\bin\$name.exe"
  if(Test-Path -LiteralPath $known -PathType Leaf){return $known}
  throw "Missing $name.exe, expected $known or use -$name full-path"
}
$compiler=Resolve-HdlTool 'iverilog' $Iverilog
$runner=Resolve-HdlTool 'vvp' $Vvp
$env:Path="$(Split-Path -Parent $compiler);$(Split-Path -Parent $runner);$env:Path"
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo=(Resolve-Path (Join-Path $root '..\..\..')).Path
$font=Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_font_8x12.hex'
$cdc=Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_tty_byte_cdc.v'
$temp=Join-Path $root 'build\icarus'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
if(-not(Test-Path -LiteralPath $font)){throw "Missing font: $font"}
if(-not(Test-Path -LiteralPath $cdc)){throw "Missing CDC: $cdc"}
Copy-Item -LiteralPath $font -Destination (Join-Path $temp 'lab04_font_8x12.hex') -Force
Push-Location $temp
try {
  foreach($test in @('renderer','reset_ctrl')){
    $out=Join-Path $temp "$test.vvp"
    if(Test-Path $out){Remove-Item $out -Force}
    if($test -eq 'renderer'){
      $sources=@((Join-Path $root 'tests\tb_renderer.v'),(Join-Path $root 'rtl\pikosol20k_renderer.v'),$cdc)
    } else {
      $sources=@((Join-Path $root 'tests\tb_reset_ctrl.v'),(Join-Path $root 'rtl\pikosol20k_reset_ctrl.v'))
    }
    & $compiler -g2012 -s "tb_$test" -o $out @sources
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $out -PathType Leaf)){throw "Icarus compile failed: $test"}
    & $runner $out
    if($LASTEXITCODE -ne 0){throw "Icarus simulation failed: $test"}
  }
} finally {Pop-Location}
