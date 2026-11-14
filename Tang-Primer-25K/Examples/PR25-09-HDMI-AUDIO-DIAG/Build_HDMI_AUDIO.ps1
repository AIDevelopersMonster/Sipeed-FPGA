# PR25-09: Gowin CLI build only, with evidence log. No FPGA programming.
param([string]$GowinShell = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe')
$ErrorActionPreference = 'Stop'
if (!(Test-Path -LiteralPath $GowinShell)) { throw "Missing Gowin: $GowinShell" }
$root = $PSScriptRoot
$sourceIP = Join-Path $root '..\..\..\ip\hdmi\a2600nano-primer25k\vendor\src\hdmi\hdmi.sv'
if (!(Test-Path -LiteralPath $sourceIP)) { throw "Missing required IP library: $sourceIP" }
$fs = Join-Path $root 'impl\pnr\pr25_hdmi_audio_diag.fs'
$started = [DateTime]::UtcNow
$ev = Join-Path $root 'evidence'
New-Item -Path $ev -ItemType Directory -Force | Out-Null
$log = Join-Path $ev ('PR25_09_BUILD_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
Push-Location $root
try {
    & $GowinShell 'Build_HDMI_AUDIO.tcl' 2>&1 | Tee-Object -FilePath $log
    $exit = $LASTEXITCODE
} finally { Pop-Location }
Write-Host "GOWIN EXIT: $exit"
Write-Host "LOG: $log"
if ($exit -ne 0) { throw 'Gowin failed; check the full log' }
if (!(Test-Path -LiteralPath $fs)) { throw "FS not generated: $fs" }
if ((Get-Item $fs).LastWriteTimeUtc -lt $started.AddSeconds(-5)) { throw "FS is stale: $fs" }
Write-Host 'BUILD COMPLETED; REVIEW TIMING REPORTS BEFORE PROGRAMMING; BOARD NOT TESTED'
Get-Item -LiteralPath $fs | Select-Object FullName,Length,LastWriteTime
Get-FileHash -LiteralPath $fs -Algorithm SHA256
