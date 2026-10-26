#requires -Version 7.0
# KonSol RS-004 candidate build. No FPGA SRAM/Flash programming performed.
[CmdletBinding()]
param([string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
$vendor = Join-Path $repo '01-PicoRV32\vendor\picotiny_ref'
if (-not (Test-Path $gw)) { throw "Gowin CLI missing: $gw" }
if (-not (Test-Path (Join-Path $vendor 'SOURCE_PIN.txt'))) {
    throw 'Pinned SVO missing. Run 01-PicoRV32\lab04\tools\fetch_picotiny.ps1 first.'
}
$pin = Get-Content (Join-Path $vendor 'SOURCE_PIN.txt') -Raw
if (-not $pin.Contains('c3b795799f23de91982be52db4273a8eea100cdb')) {
    throw 'STOP: unexpected SVO revision; compare LAB-04 source pin.'
}
$manifest = Join-Path $vendor 'SOURCE_SHA256.txt'
if (-not (Test-Path $manifest)) { throw 'STOP: vendor SHA256 manifest absent.' }
$entries = @(Get-Content $manifest)
if ($entries.Count -ne 11) { throw 'STOP: expected 11 pinned SVO files.' }
foreach ($entry in $entries) {
    if ($entry -cnotmatch '^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$') {
        throw "Invalid vendor hash entry: $entry"
    }
    $expectedHash = $Matches[1]; $relativeName = $Matches[2]
    if ($relativeName.Contains('..')) { throw 'Parent path prohibited' }
    $full = Join-Path $vendor $relativeName
    if (-not (Test-Path $full)) { throw "Missing vendor source: $relativeName" }
    if ((Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant() -cne $expectedHash) {
        throw "Vendor source hash mismatch: $relativeName"
    }
}
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$work=Join-Path $PSScriptRoot "build\$stamp\work"
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach ($dir in @('kblocks\rtl','kblocks\constraints','lab04\rtl','rtl','vendor\picotiny_ref')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $work $dir) | Out-Null
}
Copy-Item (Join-Path $PSScriptRoot 'rtl\*.v') (Join-Path $work 'kblocks\rtl')
Copy-Item (Join-Path $PSScriptRoot 'constraints\*') (Join-Path $work 'kblocks\constraints')
Copy-Item (Join-Path $repo '01-PicoRV32\lab04\rtl\lab04_video_clocks.v') (Join-Path $work 'lab04\rtl')
Copy-Item (Join-Path $repo '01-PicoRV32\rtl\uart_rx_8n1.v') (Join-Path $work 'rtl')
Copy-Item (Join-Path $vendor 'hw') (Join-Path $work 'vendor\picotiny_ref') -Recurse
Copy-Item (Join-Path $vendor 'gowin_ip') (Join-Path $work 'vendor\picotiny_ref') -Recurse
Copy-Item (Join-Path $vendor 'hw\hdmi\svo_defines.vh') (Join-Path $work 'svo_defines.vh')
Copy-Item (Join-Path $PSScriptRoot 'build.tcl') (Join-Path $work 'build.tcl')
Push-Location $work
try {
    & $gw build.tcl *> (Join-Path $work 'gowin.log')
    if ($LASTEXITCODE -ne 0) { throw "Gowin failed: $work\gowin.log" }
} finally { Pop-Location }
$fs=@(Get-ChildItem $work -Filter 'konsol_kblocks_rgb_nano9k.fs' -File -Recurse)
if ($fs.Count -ne 1) { throw "Missing or ambiguous bitstream. See $work\gowin.log" }
Write-Host "RS004_CANDIDATE=$($fs[0].FullName)" -ForegroundColor Green
Write-Host "RS004_SHA256=$((Get-FileHash $fs[0].FullName -Algorithm SHA256).Hash)"
Write-Warning 'CANDIDATE ONLY: check full post-route STA before SRAM programming. No hardware testing here.'
