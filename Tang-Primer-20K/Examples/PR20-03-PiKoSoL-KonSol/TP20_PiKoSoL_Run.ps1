#requires -Version 7.0
<#
PiKoSoL TP20: original THLN33 PicoRV32 FPGA bitstream, custom RV32I
UART/HDMI monitor, second RAM-loaded program via XMODEM-CRC.
SRAM ONLY. NEVER flashes FPGA configuration memory.
Usage:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\TP20_PiKoSoL_Run.ps1 -PrepareOnly
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\TP20_PiKoSoL_Run.ps1 -BoardTest -Port COM10 -Demo
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\TP20_PiKoSoL_Run.ps1 -Attach -Port COM10
#>
[CmdletBinding()]
param(
    [switch]$PrepareOnly,
    [switch]$BoardTest,
    [switch]$Attach,
    [switch]$Demo,
    [string]$Port = 'COM10',
    [string]$Python = 'python',
    [Nullable[int]]$CableIndex = $null,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$fw = Join-Path $root 'firmware'
$bit = Join-Path $root 'tp20k_System_picorv32.fs'
$monitor = Join-Path $fw 'monitor.bin'
$demoFile = Join-Path $fw 'demo.bin'
$hostTool = Join-Path $root 'tools\host_console.py'
$expectedBlob = '5bb54a84311a62e1b0aadd11671c399561838b24'
$expectedLength = 7262004
$source = 'https://raw.githubusercontent.com/THLN33/System_picoRV32/d3e24d9176c9361cb583111775f39a9a08cabf52/binary/tp20k_System_picorv32.fs'

function Assert-File([string]$File) {
    if (!(Test-Path -LiteralPath $File -PathType Leaf)) { throw "MISSING FILE: $File" }
}
function Get-GitBlobSHA1([string]$File) {
    [byte[]]$bytes = [System.IO.File]::ReadAllBytes($File)
    [byte[]]$prefix = [System.Text.Encoding]::ASCII.GetBytes("blob $($bytes.Length)`0")
    $st = [System.IO.MemoryStream]::new()
    try {
        $st.Write($prefix, 0, $prefix.Length)
        $st.Write($bytes, 0, $bytes.Length)
        $st.Position = 0
        $sha = [System.Security.Cryptography.SHA1]::Create()
        try { return [Convert]::ToHexString($sha.ComputeHash($st)).ToLowerInvariant() }
        finally { $sha.Dispose() }
    } finally { $st.Dispose() }
}

foreach ($file in @($monitor,$demoFile,$hostTool)) { Assert-File $file }
Write-Host '=== PiKoSoL TP20 PicoRV32 / UART + HDMI / no Flash ===' -ForegroundColor Cyan
$hash = (Get-FileHash -LiteralPath $monitor -Algorithm SHA256).Hash
$demoHash = (Get-FileHash -LiteralPath $demoFile -Algorithm SHA256).Hash
if ($hash -ne '414D8B9859CE95826E9A0BA12A26E820AF2942CD4FD964EA9FF75AC28AE135C7') { throw 'MONITOR HASH MISMATCH' }
if ($demoHash -ne 'BE20FB6EC6D1C7BFE1E9591F0C734649C61D200217F5EBF15800B4F4E681DE26') { throw 'DEMO HASH MISMATCH' }
Write-Host "MONITOR SHA256 PASS: $hash"
Write-Host "DEMO SHA256 PASS:    $demoHash"

if (!$Attach) {
    if (!(Test-Path -LiteralPath $bit -PathType Leaf)) {
        Write-Host 'Downloading official TP20 PicoRV32 FPGA bitstream...'
        Invoke-WebRequest -Uri $source -OutFile $bit -MaximumRedirection 5 -TimeoutSec 180
    }
    $item = Get-Item -LiteralPath $bit
    if ($item.Length -ne $expectedLength) { throw "UNEXPECTED FPGA FS LENGTH: $($item.Length)" }
    $blob = Get-GitBlobSHA1 $bit
    if ($blob -ne $expectedBlob) { throw "FPGA FS HASH MISMATCH: $blob" }
    Write-Host "OFFICIAL FPGA FS GIT SHA1 PASS: $blob" -ForegroundColor Green
    Write-Host "FS: $bit"
}
if ($PrepareOnly) {
    Write-Host 'PREPARE PASS / BOARD UNKNOWN. No FPGA programming performed.' -ForegroundColor Green
    return
}
if (!($BoardTest -or $Attach)) {
    Write-Host 'No board operation selected. Use -BoardTest -Demo or -PrepareOnly.'
    return
}
Assert-File $hostTool
& $Python -c 'import serial'
if ($LASTEXITCODE -ne 0) {
    throw 'PYTHON PySerial missing. Install once: python -m pip install pyserial'
}
if ($BoardTest) {
    Assert-File $Programmer
    Write-Host 'SRAM PROGRAM ONLY --run 2 (no Flash)' -ForegroundColor Cyan
    # Use Gowin Programmer's default cable selection, as in the previously
    # successful TP20-01 JTAG scan. Do not force cable index 1 here: on
    # 2026-11-19 that selected an unrelated General ID 0x1E200A6D.
    # Only supply --cable-index when the operator explicitly requested one.
    $programArgs = @('--device', 'GW2A-18C', '--run', '2', '--fsFile', $bit)
    if ($null -ne $CableIndex) { $programArgs += @('--cable-index', [string]$CableIndex) }
    Write-Host ('Programmer: ' + ($programArgs -join ' '))
    & $Programmer @programArgs
    if ($LASTEXITCODE -ne 0) { throw "FPGA SRAM PROGRAM FAILED (exit $LASTEXITCODE)" }
    Write-Host 'SRAM PROGRAM CLI PASS; BOARD UNKNOWN until serial + HDMI.'
}
$pyArgs = @('-B', $hostTool, '--port', $Port, '--baud', '115200', '--monitor', $monitor, '--demo', $demoFile)
if ($Attach) { $pyArgs += '--attach' }
if ($Demo) { $pyArgs += '--auto-demo' }
Write-Host "Starting UART console on $Port at 115200 baud. Close MobaXterm / loader.exe." -ForegroundColor Cyan
& $Python @pyArgs
if ($LASTEXITCODE -ne 0) { throw "HOST CONSOLE FAILED with exit code $LASTEXITCODE" }
Write-Host 'TP20 PiKoSoL session ended; no FPGA Flash touched.'
