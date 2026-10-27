#requires -Version 7.0
<#
LAB-06.2C — one-command, SHA-locked PicoRV32 board smoke test.
Never generates a new bitstream. Programmer: GW1NR-9C operation_index 2,
volatile SRAM only. UART capture after SRAM write requires manual S1 reset.
NO Flash, SD, benchmark, or full STA acceptance.
Examples:
  .\01-PicoRV32\lab06\tools\smoke_lab062_board.ps1
  .\01-PicoRV32\lab06\tools\smoke_lab062_board.ps1 -Program -Port COM10
#>
[CmdletBinding()]
param(
    [switch]$Program,
    [string]$Port='COM10',
    [ValidateRange(5,120)][int]$CaptureSeconds=25,
    [ValidateRange(1,8)][int]$CableIndex=1
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false

$lab = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$repo = (Resolve-Path -LiteralPath (Join-Path $lab '..\..\..')).Path
$job = Join-Path $lab '_build\fit_20261026_174759_839_3ed614'
$fs = Join-Path $job 'lab062_pico_nano9k.fs'
$fitReceipt = Join-Path $job 'fit_receipt.json'
$expectedSHA='31691075B56BB4167758AEB9D99CE8E7F4CE0BE84333D527FD2659606025F4A0'
$programmer = Join-Path $repo '01-PicoRV32\lab04\tools\program_lab04_sram.ps1'
$capture = Join-Path $lab 'tools\capture_lab062_uart.py'

foreach ($f in @($fs,$fitReceipt,$programmer,$capture)) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) {
        throw "LAB062_REQUIRED_FILE_MISSING: $f"
    }
}
if ((Split-Path $fs -Leaf) -cne 'lab062_pico_nano9k.fs') {
    throw 'LAB062_WRONG_FILENAME'
}
$actualSHA=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($actualSHA -cne $expectedSHA) {
    throw "LAB062_BITSTREAM_SHA256_FAIL: $actualSHA"
}
$r=Get-Content -LiteralPath $fitReceipt -Raw -Encoding utf8 | ConvertFrom-Json
if ($r.Stage -cne 'LAB062_FIT' -or
    $r.UpstreamCommit -cne 'ef203c2b0a3fb793280f5114941416c425c5b461' -or
    $r.SimStatus -cne 'PASS' -or
    $r.PnR -cne 'PASS' -or
    [string]$r.BitstreamCandidateSHA256 -cne $expectedSHA) {
    throw 'LAB062_FIT_PROVENANCE_FAIL: wrong candidate or missing SIM/PnR PASS'
}

Write-Host "LAB062_EXACT_IMAGE_VERIFIED: $actualSHA" -ForegroundColor Green
Write-Host "LAB062_BITSTREAM_FILE: $fs"
Write-Host 'LAB062_STA_CAVEAT: Recovery/Removal have NO reported paths; asynchronous reset release NOT timing-qualified.' -ForegroundColor Yellow
if (-not $Program) {
    Write-Host 'LAB062_DRY_RUN_ONLY: pass -Program to load this exact image into VOLATILE SRAM and capture UART.'
    exit 0
}

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    throw 'LAB062_PYTHON_NOT_FOUND: install Python/pyserial before attempting board capture'
}
& python -c 'import serial'
if ($LASTEXITCODE -ne 0) {
    throw 'LAB062_PYSERIAL_NOT_FOUND: run python -m pip install pyserial (once)'
}
$session = Join-Path $lab ('_build\board_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -Path $session -ItemType Directory -Force | Out-Null
$raw = Join-Path $session 'uart_raw.bin'
$uartLog = Join-Path $session 'uart_capture.log'
$receiptPath = Join-Path $session 'board_receipt.json'
$board=[ordered]@{
    Schema='LAB062_BOARD_SMOKE_V1'
    DateUtc=(Get-Date).ToUniversalTime().ToString('o')
    Candidate=$fs
    BitstreamSHA256=$actualSHA
    FitJob=$job
    Port=$Port
    Programmer='NOT_RUN'
    UART='NOT_RUN'
    LED='OPERATOR_CONFIRMATION_PENDING'
    Reset='NOT_QUALIFIED'
    Board='NOT_ACCEPTED'
    Flash='NOT_TOUCHED'
    SD='NOT_TOUCHED'
    UartRaw=$raw
    UartLog=$uartLog
}
function Write-Receipt {
    $board | ConvertTo-Json -Depth 5 |
        Set-Content -LiteralPath $receiptPath -Encoding utf8
}
Write-Receipt
Write-Host 'LAB062_PROGRAM_START: close all terminal windows and WebSerial first.'
try {
    & $programmer -Bitstream $fs -CableIndex $CableIndex -Program
    $board.Programmer='PASS'
    Write-Receipt
    Write-Host 'LAB062_SRAM_PROGRAM_PASS: exact PicoRV32 image; NOT KBlocks.' -ForegroundColor Green
} catch {
    $board.Programmer='FAIL'
    Write-Receipt
    Write-Host "LAB062_RECEIPT: $receiptPath"
    throw
}

Write-Host 'LAB062_UART_CAPTURE: after the port opens press S1 once to emit PICORV32 READY.' -ForegroundColor Cyan
& python -u $capture --port $Port --seconds $CaptureSeconds --raw $raw *>&1 |
    Tee-Object -FilePath $uartLog
$serialExit = $LASTEXITCODE
if ($serialExit -eq 0) {
    $board.UART='PASS'
    $board.Board='UART_PASS_LED_PENDING'
    Write-Host 'LAB062_UART_BOARD_PASS: RISC-V banner received. Confirm THREE alternating LEDs physically.' -ForegroundColor Green
} else {
    $board.UART='FAIL_OR_NOT_CAPTURED'
    Write-Host 'LAB062_UART_NOT_CONFIRMED: inspect COM port, press S1 and do NOT claim board PASS.' -ForegroundColor Yellow
}
Write-Receipt
Write-Host "LAB062_BOARD_RECEIPT: $receiptPath"
Write-Host "LAB062_UART_LOG: $uartLog"
Write-Host 'LAB062_BOARD_ACCEPTANCE: ONLY after operator verifies 3 LEDs and records their state.'
if ($serialExit -ne 0) {
    throw "LAB062_UART_CAPTURE_FAILED: exit=$serialExit; no hardware PASS"
}
