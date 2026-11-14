# PR25-05 / UARTTX-01 - standalone UART text beacon (no FPGA Flash writes).
param(
    [string]$Work = 'C:\GitHub\TangPrimer25K_UART_TX',
    [string]$GowinRoot = 'C:\Gowin'
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$raw = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-05-UART-TX'
$inputs = @('src/top.v', 'src/pins.cst', 'src/timing.sdc')
New-Item -ItemType Directory -Path $Work -Force | Out-Null
foreach ($f in $inputs) {
    $target = Join-Path $Work $f
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Invoke-WebRequest -Uri "$raw/$f" -OutFile $target
    if ((Get-Item $target).Length -eq 0) { throw "Empty source: $target" }
}
$exe = @(Get-ChildItem -Path $GowinRoot -Filter 'gw_sh.exe' -File -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -match 'IDE\\bin\\gw_sh\.exe$' } |
    Sort-Object FullName -Descending | Select-Object -First 1)
if (!$exe) { throw "gw_sh.exe not found" }
$lines = @(
    'set_device -name GW5A-25A GW5A-LV25MG121NC1/I0'
    'set_option -top_module top'
    'set_option -output_base_name pr25_uart_tx'
    'set_option -use_cpu_as_gpio 1'
    'add_file src/top.v'
    'add_file src/pins.cst'
    'add_file src/timing.sdc'
    'run all'
)
$tcl = Join-Path $Work 'build_uart_tx.tcl'
[System.IO.File]::WriteAllLines($tcl, $lines, [System.Text.UTF8Encoding]::new($false))
$evidence = Join-Path $Work 'evidence'
New-Item -ItemType Directory -Path $evidence -Force | Out-Null
$log = Join-Path $evidence ("UARTTX_BUILD_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
$started = [DateTime]::UtcNow
Write-Host "UARTTX: build for GW5A-25A (SRAM/Flash untouched)"
Write-Host "WORK: $Work"
Write-Host "LOG:  $log"
Push-Location $Work
try {
    & $exe[0].FullName $tcl 2>&1 | Tee-Object -FilePath $log
    $code = $LASTEXITCODE
} finally { Pop-Location }
Write-Host "GOWIN EXIT: $code"
if ($code -ne 0) { throw "Gowin build failure, inspect $log" }
$fs = Join-Path $Work 'impl\pnr\pr25_uart_tx.fs'
if (!(Test-Path $fs)) { throw "Missing bitstream: $fs" }
if ((Get-Item $fs).LastWriteTimeUtc -lt $started.AddSeconds(-2)) {
    throw 'Bitstream stale: build not verified'
}
$hash = (Get-FileHash -Path $fs -Algorithm SHA256).Hash
Write-Host 'UARTTX BUILD PASS (BOARD NOT TESTED)'
Write-Host "FILE: $fs"
Write-Host "SHA256: $hash"
Write-Host 'TX wire: C3, 50 MHz clock: E2, 9600 8N1'
