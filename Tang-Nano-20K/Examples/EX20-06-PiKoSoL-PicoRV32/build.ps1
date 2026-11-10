# PiKoSoL 20K, GW2AR-18C: reproducible local build, NEVER programs FPGA.
[CmdletBinding()]
param(
  [string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education',
  [string]$Python='python',
  [switch]$StageOnly
)
$ErrorActionPreference='Stop'
$project=$PSScriptRoot
$repo=(Resolve-Path (Join-Path $project '..\..\..')).Path
$stageScript=Join-Path $project 'tools\stage.py'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
$vendor=Join-Path $repo 'Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\vendor'

foreach($name in @('TMDS_rPLL.v','dvi_tx.v')) {
  if(-not (Test-Path (Join-Path $vendor $name))) {
    Write-Host "Missing Sipeed 20K HDMI vendor source: $name. Fetching pinned EX20-05 vendor..."
    & (Join-Path $repo 'Tang-Nano-20K\Examples\EX20-05-CPU-HDMI\prepare_vendor.ps1')
    if($LASTEXITCODE -ne 0){ throw 'Vendor source fetch failed' }
    break
  }
}
$pico=Join-Path $repo '01-PicoRV32\vendor\picorv32\picorv32.v'
if(-not(Test-Path -LiteralPath $pico)) {
  Write-Host 'Fetching pinned PicoRV32 (original 9K pin)...'
  & (Join-Path $repo '01-PicoRV32\tools\fetch_picorv32.ps1')
  if($LASTEXITCODE -ne 0){ throw 'PicoRV32 source fetch failed' }
}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss_fff'
$job=Join-Path $project ('build\candidate_'+$stamp)
$work=Join-Path $job 'work'
New-Item -ItemType Directory -Path $job -Force | Out-Null
& $Python $stageScript --repo $repo --out $work
if($LASTEXITCODE -ne 0){throw 'Source preparation failed; no programming attempted'}
Write-Host "PIKOSOL20K_STAGE=$work"
if($StageOnly) {
  Write-Host 'STAGE_ONLY_PASS: no synthesis, no JTAG, no Flash'
  return
}
if(-not(Test-Path $gw -PathType Leaf)){throw "Gowin executable missing: $gw"}
Push-Location $work
try {
  & $gw gowin_build.tcl *> (Join-Path $job 'gowin.log')
  $rc=$LASTEXITCODE
} finally {Pop-Location}
if($rc -ne 0) { throw "GOWIN_BUILD_FAIL rc=$rc : $job\gowin.log" }
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -Filter 'pikosol20k_picorv32_candidate.fs' -File)
if($bits.Count -ne 1){throw "Expected one .fs, found $($bits.Count); inspect $job"}
$fs=$bits[0]
Write-Host "GOWIN_CANDIDATE=$($fs.FullName)"
Write-Host "SHA256=$((Get-FileHash -LiteralPath $fs.FullName -Algorithm SHA256).Hash)"
Write-Host 'NOTE: synthesis completed, but PNR/STA and hardware acceptance must be examined.'
Write-Host 'FLASH NEVER TOUCHED; THIS SCRIPT NEVER PROGRAMS THE BOARD.'
