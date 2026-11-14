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
Push-Location $src
try {
    & $GowinShell 'build_tp25k.tcl' 2>&1 | Tee-Object -FilePath $log
    $exitCode=$LASTEXITCODE
}
finally {Pop-Location}
Write-Host "GOWIN EXIT: $exitCode"
if ($exitCode -ne 0){throw 'Gowin build failed; review log, keep GOLDEN'}
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
 build_script='UNMODIFIED build_tp25k.tcl'
 tool=$GowinShell;log=$log;workspace=$src
 bitstream=$copy;bitstream_size=(Get-Item $copy).Length;bitstream_sha256=$hash
 sta='NOT_AUTOMATICALLY_VERIFIED';audio='NOT_TESTED'
} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifest -Encoding utf8
Write-Host "BUILD PASS. FS: $copy"
Write-Host "SHA256: $hash"
Write-Host "Manifest: $manifest"
Write-Host 'Check STA setup/hold BEFORE FPGA SRAM programming.'
