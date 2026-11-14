# PR25-06: no-clock, no-reset constant HIGH C3 UART line, CLI build, no hardware writes.
param([string]$Work='C:\GitHub\TangPrimer25K_UART_IDLE',[string]$GowinRoot='C:\Gowin')
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$root='https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-06-UART-IDLE'
foreach($name in @('src/top.v','src/pins.cst')) {
  $target=Join-Path $Work $name
  New-Item -ItemType Directory -Force (Split-Path -Parent $target) | Out-Null
  Invoke-WebRequest "$root/$name" -OutFile $target
}
$exe=@(Get-ChildItem $GowinRoot -Filter gw_sh.exe -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object {$_.FullName -match 'IDE\\bin\\gw_sh\.exe$'} |
  Sort-Object FullName -Descending | Select-Object -First 1)
if(!$exe){throw 'gw_sh not found'}
$script=Join-Path $Work 'build_idle.tcl'
@(
  'set_device -name GW5A-25A GW5A-LV25MG121NC1/I0'
  'set_option -top_module top'
  'set_option -output_base_name pr25_uart_idle'
  'add_file src/top.v'
  'add_file src/pins.cst'
  'run all'
) | Set-Content -Encoding ascii $script
$start=[DateTime]::UtcNow
Push-Location $Work
try { & $exe[0].FullName $script; $code=$LASTEXITCODE } finally { Pop-Location }
Write-Host "GOWIN EXIT: $code"
if($code -ne 0){ throw "Build failed: $code" }
$fs=Join-Path $Work 'impl\pnr\pr25_uart_idle.fs'
if(!(Test-Path $fs)){throw "Bitstream absent: $fs"}
if((Get-Item $fs).LastWriteTimeUtc -lt $start.AddSeconds(-2)){throw 'Stale bitstream'}
Write-Host "UART IDLE BUILD PASS: $fs"
Write-Host "SHA256: $((Get-FileHash $fs -Algorithm SHA256).Hash)"
