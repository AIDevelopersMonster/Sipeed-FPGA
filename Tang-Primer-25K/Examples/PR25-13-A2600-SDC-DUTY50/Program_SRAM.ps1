#Requires -Version 7.0
# PR25-13 -- FPGA SRAM only; never Flash. Requires deliberate -Program.
[CmdletBinding()]
param(
    [switch]$Program,
    [int]$CableIndex=1,
    [string]$Programmer='C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if (-not $Program){throw 'Nothing programmed. Pass -Program after manual STA review.'}
$art=Join-Path $PSScriptRoot 'artifacts'
$mf=Join-Path $art 'sdc50_manifest.json'
$fs=Join-Path $art 'a2600nano_tp25k_SDC50.fs'
if (!(Test-Path -LiteralPath $mf) -or !(Test-Path -LiteralPath $fs)){
    throw 'Missing verified build manifest or bitstream; run Build_SDC50.ps1 first.'
}
$m=Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
if ($m.status -ne 'BUILD_PASS_STA_REVIEW_REQUIRED' -or
    $m.source_commit -ne '705bf787675579721d339806cb522905dec73ed3') {
    throw 'Unexpected source or build status'
}
$hash=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $m.bitstream_sha256 -or
    (Get-Item -LiteralPath $fs).Length -ne [int64]$m.bitstream_size) {
    throw 'Bitstream SHA256 or size does not match manifest'
}
if (!(Test-Path -LiteralPath $Programmer)){throw 'Gowin Programmer unavailable'}
$ev=Join-Path $PSScriptRoot 'evidence'
New-Item -Path $ev -ItemType Directory -Force | Out-Null
$log=Join-Path $ev ('PR25_13_SRAM_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff')+'.txt')
Start-Transcript -LiteralPath $log | Out-Null
try {
    Write-Host 'PR25-13 SDC50 EXPERIMENTAL IMAGE, NOT GOLDEN.'
    Write-Host 'Manual STA review is required; the script cannot certify STA pass.'
    Write-Host "FS: $fs"
    Write-Host "SHA256: $hash"
    Write-Host 'FPGA SRAM --run 2 ONLY; no external Flash writes.'
    & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
    $status=$LASTEXITCODE
    Write-Host "SRAM PROGRAM EXIT: $status"
    if ($status -ne 0){throw "Programming failed: $status"}
    Write-Host 'Observe HDMI video and sound. Exit 0 does NOT imply board PASS.'
    Write-Host 'If screen is black, restore original PR25-11 -Variant Golden.'
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "LOG: $log"
}
