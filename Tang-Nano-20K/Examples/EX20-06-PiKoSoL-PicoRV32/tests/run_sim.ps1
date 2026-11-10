# Icarus renderer smoke simulation. No Gowin IP and no FPGA programming.
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo=(Resolve-Path (Join-Path $root '..\..\..')).Path
$font=Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_font_8x12.hex'
$cdc=Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_tty_byte_cdc.v'
if(-not(Test-Path $font)){throw '9K font reference not found'}
$temp=Join-Path $root 'build\icarus'
New-Item -ItemType Directory -Force -Path $temp | Out-Null
Copy-Item -LiteralPath $font -Destination (Join-Path $temp 'lab04_font_8x12.hex') -Force
Push-Location $temp
try {
  & iverilog -g2012 -s tb_renderer -o renderer.vvp `
      (Join-Path $root 'tests\tb_renderer.v') `
      (Join-Path $root 'rtl\pikosol20k_renderer.v') $cdc
  if($LASTEXITCODE -ne 0){throw 'Icarus compile failed'}
  & vvp .\renderer.vvp
  if($LASTEXITCODE -ne 0){throw 'Icarus simulation failed'}
} finally { Pop-Location }
