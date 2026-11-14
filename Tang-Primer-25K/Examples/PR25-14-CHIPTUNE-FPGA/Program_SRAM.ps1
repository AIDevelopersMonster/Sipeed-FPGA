#Requires -Version 7.0
# PR25-14 FPGA SRAM only; never Flash. Required -Program switch.
[CmdletBinding()]
param(
  [switch]$Program,
  [int]$CableIndex=1,
  [string]$Programmer='C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
if(!$Program){throw 'No programming performed. Pass -Program after build + STA review.'}
$manifestPath=Join-Path $PSScriptRoot 'artifacts\PR25_14_manifest.json'
if(!(Test-Path -LiteralPath $manifestPath)){throw 'PR25-14 build manifest is missing'}
$m=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
if($m.status -ne 'BUILD_PASS_STA_REVIEW_REQUIRED' -or
   $m.upstream_commit -ne '705bf787675579721d339806cb522905dec73ed3'){
  throw 'Manifest build provenance does not match required baseline'
}
$fs=Join-Path $PSScriptRoot 'artifacts\chipmusic_tp25k_PR25_14.fs'
if(!(Test-Path -LiteralPath $fs)){throw "Missing .fs: $fs"}
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
if($sha -ne $m.bitstream_sha256 -or
   (Get-Item -LiteralPath $fs).Length -ne [int64]$m.bitstream_size){
  throw 'Firmware SHA256 or byte size mismatch; refusing to program'
}
if(!(Test-Path -LiteralPath $Programmer)){throw "Missing Gowin Programmer: $Programmer"}
$ev=Join-Path $PSScriptRoot 'evidence';New-Item -Path $ev -ItemType Directory -Force|Out-Null
$log=Join-Path $ev ('PR25_14_SRAM_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff')+'.txt')
Start-Transcript -LiteralPath $log | Out-Null
try {
 Write-Host 'EXPERIMENTAL PR25-14: independent animated pixel art + original 3-voice music'
 Write-Host "FS: $fs"
 Write-Host "SHA256: $sha"
 Write-Host 'VOLATILE SRAM ONLY --run 2; no Flash writes.'
 & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
 $code=$LASTEXITCODE
 Write-Host "SRAM PROGRAM EXIT: $code"
 if($code -ne 0){throw "Program failed $code"}
 Write-Host 'Observe the pixel scene, moving equalizer and audible music separately.'
 Write-Host 'If needed, restore PR25-13 firmware using its own SRAM Program script.'
} finally {Stop-Transcript|Out-Null;Write-Host "LOG: $log"}
