# TP20-01 nano-Z80. Download and optionally load into VOLATILE FPGA SRAM.
# Never writes FPGA configuration flash. Source: upstream release; operator validates PLL first.
[CmdletBinding()]
param(
    [switch]$LoadSRAM,
    [string]$BitstreamUrl = 'https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.fs'
)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $PSScriptRoot 'downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$fs = Join-Path $dir 'nano-z80.fs'
$hashfile = Join-Path $dir 'nano-z80.sha256.txt'

Write-Host "UPSTREAM: $BitstreamUrl"
if (-not (Test-Path -LiteralPath $fs)) {
    Invoke-WebRequest -Uri $BitstreamUrl -OutFile $fs -MaximumRedirection 10
}
$file = Get-Item -LiteralPath $fs
if ($file.Length -lt 1024) { throw "Bitstream too small ($($file.Length) bytes); refusing to program" }
$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
"SHA256=$hash`nSIZE=$($file.Length)`nSOURCE=$BitstreamUrl" | Set-Content -LiteralPath $hashfile -Encoding UTF8
Write-Host ("FILE : " + $fs)
Write-Host ("BYTES: " + $file.Length)
Write-Host ("SHA256: " + $hash)
Write-Host "COM port is configured separately. This script does not configure PLL."
if (-not $LoadSRAM) {
    Write-Host "Downloaded/verified file only. To program TEMPORARY SRAM, use: .\get-nano-z80.ps1 -LoadSRAM"
    exit 0
}
$loader = Get-Command openFPGALoader -ErrorAction SilentlyContinue
if (-not $loader) { throw "openFPGALoader not found in PATH; no programming occurred" }
Write-Warning "Check external PLL O0=25.175MHz and O1=12MHz and record prior settings BEFORE proceeding."
Write-Warning "The factory LiteX SRAM image will be replaced until power-cycle; FLASH MUST REMAIN UNTOUCHED."
$confirm = Read-Host "Enter exactly SRAM to program volatile configuration (anything else cancels)"
if ($confirm -cne 'SRAM') { throw 'Cancelled by operator; no programming occurred' }
$loaderPath = $loader.Source
& $loaderPath '-b' 'tangnano20k' $fs
if ($LASTEXITCODE -ne 0) { throw "openFPGALoader SRAM load FAILED, exit code $LASTEXITCODE" }
Write-Host "SRAM loader exited 0. This does NOT mean HDMI/UART BOARD PASS; test those separately."
