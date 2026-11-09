# EX20-01 HDMI Tang Nano 20K: safe Gowin Programmer CLI SRAM-only workflow.
# Default: preflight and preview ONLY. -Scan probes cable/device; -Program does SRAM write.
[CmdletBinding()]
param(
  [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education',
  [string]$Bitstream = (Join-Path $PSScriptRoot 'artifacts\sipeed_hdmi_20k.fs'),
  [ValidateSet(0,1,2,3)][int]$CableIndex = 1,
  [switch]$Scan,
  [switch]$Program
)
$ErrorActionPreference = 'Stop'
$expectedHash = 'cb024d255692321a9b7fa22cf603dd89d1cd7875930ad57e00fd2bccf6cf9b0a'
$expectedBytes = 4619320
$programmer = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
if (-not (Test-Path -LiteralPath $programmer -PathType Leaf)) {
  throw "Programmer CLI not found: $programmer"
}
if (-not (Test-Path -LiteralPath $Bitstream -PathType Leaf)) {
  throw "Bitstream missing. Run prepare_hdmi.ps1 first: $Bitstream"
}
$fs = (Resolve-Path -LiteralPath $Bitstream).Path
if (-not $fs.EndsWith('.fs',[StringComparison]::OrdinalIgnoreCase)) { throw 'Expected .fs file' }
$size = (Get-Item -LiteralPath $fs).Length
$sha = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
if ($size -ne $expectedBytes -or $sha -ne $expectedHash) {
  throw "Source fingerprint mismatch: bytes=$size SHA256=$sha. Refusing FPGA operation."
}
Write-Host 'EX20-01 HDMI FILE VERIFIED'
Write-Host "FILE: $fs"
Write-Host "BYTES: $size"
Write-Host "SHA256: $sha"
Write-Host "PROGRAMMER: $programmer"
Write-Host "DEVICE EXPECTED: GW2AR-18C (project pn GW2AR-LV18QN88C8/I7)"
Write-Host "MODE: --run 2 = SRAM Program ONLY; never Flash"
$evidence = Join-Path $PSScriptRoot 'artifacts'
New-Item -Path $evidence -ItemType Directory -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
if ($Scan -or $Program) {
  $log = Join-Path $evidence "HDMI_SCAN_$stamp.txt"
  Write-Host 'SCANNING JTAG chain (no programming)...'
  & $programmer --scan --cable-index $CableIndex 2>&1 | Tee-Object -FilePath $log
  if ($LASTEXITCODE -ne 0) { throw "Scan failed with exit $LASTEXITCODE. Log: $log" }
  Write-Host "SCAN LOG: $log"
  if (-not $Program) {
    Write-Host 'STOP: review scan output to confirm exactly the Tang Nano 20K GW2AR-18C target.'
    return
  }
  $scanText = Get-Content -LiteralPath $log -Raw
  if ($scanText -notmatch '(?i)GW2AR-18C') {
    throw 'GW2AR-18C not present in scan log. Refusing to program.'
  }
}
if (-not $Program) {
  Write-Host 'DRY RUN PASS: no FPGA write. Use -Scan to probe and -Program to explicitly enable SRAM write.'
  return
}
Write-Host 'EXPLICIT SRAM PROGRAM REQUESTED. Ensure COM25 terminals are closed, HDMI connected, and only target board on JTAG.'
$log = Join-Path $evidence "HDMI_PROGRAM_$stamp.txt"
& $programmer --device GW2AR-18C --run 2 --fsFile $fs --cable-index $CableIndex 2>&1 | Tee-Object -FilePath $log
$exitCode = $LASTEXITCODE
Write-Host "PROGRAM LOG: $log"
if ($exitCode -ne 0) { throw "Programmer exit $exitCode. BOARD PASS NOT ESTABLISHED." }
Write-Host 'SRAM PROGRAM CLI EXIT 0. This is not yet HDMI BOARD PASS: verify screen + key + power cycle + LiteX BIOS.'
