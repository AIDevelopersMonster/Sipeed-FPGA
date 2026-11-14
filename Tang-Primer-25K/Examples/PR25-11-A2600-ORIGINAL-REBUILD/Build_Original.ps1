#Requires -Version 7.0
# PR25-11: compile unchanged upstream A2600Nano v2.5. NO FPGA writes.
[CmdletBinding()]
param([string]$GowinShell='C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$expected='705bf787675579721d339806cb522905dec73ed3'
$cache=Join-Path $PSScriptRoot '_cache\A2600Nano-v2.5'
$work=Join-Path $PSScriptRoot 'work'
$art=Join-Path $PSScriptRoot 'artifacts'
$ev=Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $work,$art,$ev | Out-Null
$manifest=Join-Path $art 'rebuild_manifest.json'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmssfff'
$log=Join-Path $ev ('PR25_11_BUILD_'+$stamp+'.log')
# Invalidate any successful old manifest before attempting a new build.
@{status='STARTED';source_commit=$expected;time=(Get-Date).ToString('o')} |
  ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8
if (!(Test-Path -LiteralPath $GowinShell)){throw "Missing Gowin: $GowinShell"}
if (!(Get-Command git -ErrorAction SilentlyContinue)){throw 'git missing'}
if (!(Test-Path -LiteralPath (Join-Path $cache '.git'))) {
    New-Item -ItemType Directory -Force -Path (Split-Path $cache -Parent) | Out-Null
    & git clone --depth 1 --branch v2.5 'https://github.com/MiSTle-Dev/A2600Nano.git' $cache
    if ($LASTEXITCODE -ne 0){throw 'git clone failed'}
}
$actual=(& git -C $cache rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actual -ne $expected){
    throw "Upstream commit mismatch: expected $expected, got $actual"
}
$dirty=@(& git -C $cache status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0){
    throw 'Tracked upstream changes detected: clean source required'
}
$run=Join-Path $work ('run_'+$stamp)
$src=Join-Path $run 'src'
$zip=Join-Path $run 'original_source.zip'
New-Item -ItemType Directory -Force -Path $run,$src | Out-Null
& git -C $cache archive --format=zip --output=$zip HEAD
if ($LASTEXITCODE -ne 0){throw 'git archive failed'}
Expand-Archive -LiteralPath $zip -DestinationPath $src -Force
foreach ($p in @('build_tp25k.tcl','src/tang/primer25k/a2600_top_tp25k.vhd',
 'src/tang/primer25k/a2600_top_tp25k.cst','src/hdmi/hdmi.sv','src/misc/video.v')) {
    if (!(Test-Path -LiteralPath (Join-Path $src $p))){
        throw "Original upstream file missing: $p"
    }
}
Write-Host "PR25-11: SOURCE PASS - original commit $actual"
Write-Host "Workspace: $src"
Write-Host "Gowin log: $log"
$started=[DateTime]::UtcNow
$exitCode=-1
$scriptUsed='build_tp25k.tcl'
$initialLog=$log
$compatLog=$null
$compatTclHash=$null
$compatNote='none'
$originalTclPath=Join-Path $src 'build_tp25k.tcl'
$originalTclHash=(Get-FileHash -LiteralPath $originalTclPath -Algorithm SHA256).Hash.ToLowerInvariant()

# Original byte-exact upstream script ALWAYS runs first.
Push-Location $src
try {
    & $GowinShell $scriptUsed 2>&1 | Tee-Object -FilePath $initialLog
    $exitCode=$LASTEXITCODE
}
finally {Pop-Location}
Write-Host "GOWIN original TCL EXIT: $exitCode"

# This exact observed error is due to unsupported Gowin configuration
# loading rate in 1.9.9Beta-4, NOT HDMI audio sample rate.
# Only when seen, run a second, separate TCL file with that one line
# disabled. No modifications to any upstream RTL, original TCL, IP,
# PLL, pins or constraints. Stop for all other errors.
if ($exitCode -ne 0) {
    $unsupportedRate=Select-String -LiteralPath $initialLog -Pattern 'invalid loading_rate value' -SimpleMatch -Quiet
    if (-not $unsupportedRate) {
        throw "Gowin failed for a different reason. See original log: $initialLog"
    }
    $originalText=[IO.File]::ReadAllText($originalTclPath)
    $pattern='(?m)^[ \t]*set_option[ \t]+-loading_rate[ \t]+70\.000[ \t]*(?:\r?\n|$)'
    $count=[regex]::Matches($originalText,$pattern).Count
    if ($count -ne 1) {
        throw "Expected one loading_rate=70.000 line; found $count. Aborting."
    }
    $replacementLine='# Gowin 1.9.9 compatibility: loading-rate option omitted'+[Environment]::NewLine
    $compatText=[regex]::Replace($originalText,$pattern,$replacementLine)
    $scriptUsed='build_tp25k_compat199.tcl'
    $compatPath=Join-Path $src $scriptUsed
    [IO.File]::WriteAllText($compatPath,$compatText,[Text.UTF8Encoding]::new($false))
    $compatTclHash=(Get-FileHash -LiteralPath $compatPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $compatNote='omitted only set_option -loading_rate 70.000; all original HDL and IP unchanged'
    $compatLog=Join-Path $ev ('PR25_11_COMPAT199_'+$stamp+'.log')
    Write-Host 'Retrying Gowin with single-TCL-option compatibility change.'
    Write-Host "Original TCL SHA256: $originalTclHash"
    Write-Host "Compatibility TCL SHA256: $compatTclHash"
    Write-Host "Compatibility log: $compatLog"
    Push-Location $src
    try {
        & $GowinShell $scriptUsed 2>&1 | Tee-Object -FilePath $compatLog
        $exitCode=$LASTEXITCODE
    }
    finally {Pop-Location}
}
Write-Host "GOWIN final EXIT: $exitCode"
if ($exitCode -ne 0) {
    throw "Gowin failed. Review initial log $initialLog and retry log $compatLog. GOLDEN untouched."
}
$fs=Join-Path $src 'impl\pnr\a2600nano_tp25k.fs'
if (!(Test-Path -LiteralPath $fs)){throw 'Build exited 0 but produced no .fs'}
$item=Get-Item -LiteralPath $fs
if ($item.Length -lt 100000 -or $item.LastWriteTimeUtc -lt $started.AddSeconds(-5)){
    throw 'Generated .fs is stale or implausibly small'
}
$copy=Join-Path $art 'a2600nano_tp25k_REBUILT.fs'
Copy-Item -LiteralPath $fs -Destination $copy -Force
$hash=(Get-FileHash -LiteralPath $copy -Algorithm SHA256).Hash.ToLowerInvariant()
[ordered]@{
 status='BUILD_PASS_NOT_BOARD_TESTED';time=(Get-Date).ToString('o')
 source_repo='https://github.com/MiSTle-Dev/A2600Nano'
 source_tag='v2.5';source_commit=$expected
 build_script=$scriptUsed
 original_build_tcl_sha256=$originalTclHash
 compat_build_tcl_sha256=$compatTclHash
 compatibility_change=$compatNote
 original_build_log=$initialLog
 compat_build_log=$compatLog
 tool=$GowinShell;workspace=$src
 bitstream=$copy;bitstream_size=(Get-Item $copy).Length;bitstream_sha256=$hash
 sta='NOT_AUTOMATICALLY_VERIFIED';audio='NOT_TESTED'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest -Encoding utf8
Write-Host "BUILD PASS. FS: $copy"
Write-Host "SHA256: $hash"
Write-Host "Build TCL used: $scriptUsed"
Write-Host "Original log: $initialLog"
if ($compatLog) { Write-Host "Compatibility log: $compatLog" }
Write-Host "Manifest: $manifest"
Write-Host 'Check STA setup/hold BEFORE FPGA SRAM programming.'
