#requires -Version 7.0
[CmdletBinding()]
param([string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
$vendor = Join-Path $repo '01-PicoRV32\vendor\picotiny_ref'
if (!(Test-Path $gw)) { throw "Gowin CLI missing: $gw" }
if (!(Test-Path (Join-Path $vendor 'SOURCE_PIN.txt'))) {
    throw 'Pinned SVO dependencies missing. Use the existing LAB-04 fetch_picotiny.ps1 first.'
}
$pin = Get-Content (Join-Path $vendor 'SOURCE_PIN.txt') -Raw
if (!$pin.Contains('c3b795799f23de91982be52db4273a8eea100cdb')) {
    throw 'STOP: SVO dependency revision differs from LAB-04 pinned version.'
}
$manifest = Join-Path $vendor 'SOURCE_SHA256.txt'
if (!(Test-Path $manifest)) { throw 'STOP: no SVO SHA256 manifest.' }
$entries = @(Get-Content $manifest)
if ($entries.Count -ne 11) { throw 'STOP: expected 11 pinned SVO vendor files.' }
foreach($entry in $entries) {
    if ($entry -cnotmatch '^([a-f0-9]{64})  ([A-Za-z0-9_./-]+)$') { throw "Invalid vendor hash line: $entry" }
    $hash = $Matches[1]; $file = $Matches[2]
    if ($file.Contains('..')) { throw 'Parent path prohibited' }
    $full = Join-Path $vendor $file
    if (!(Test-Path $full)) { throw "Missing SVO vendor source: $file" }
    if ((Get-FileHash $full -Algorithm SHA256).Hash.ToLowerInvariant() -cne $hash) { throw "Vendor hash mismatch: $file" }
}
$stamp = Get-Date -Format yyyyMMdd_HHmmss
$work = Join-Path $PSScriptRoot "build\$stamp\work"
New-Item -ItemType Directory -Force -Path $work | Out-Null
foreach($dir in @('breakout\rtl','breakout\constraints','lab04\rtl','rtl','vendor\picotiny_ref')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $work $dir) | Out-Null
}
Copy-Item (Join-Path $PSScriptRoot 'rtl\*.v') (Join-Path $work 'breakout\rtl')
Copy-Item (Join-Path $PSScriptRoot 'constraints\*') (Join-Path $work 'breakout\constraints')
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
$fs = @(Get-ChildItem $work -Filter 'pikosol_breakout_rgb_nano9k.fs' -File -Recurse)
if ($fs.Count -ne 1) { throw "Missing or ambiguous bitstream; check $work" }
Write-Host "BREAKOUT_CANDIDATE=$($fs[0].FullName)"
Write-Host "SHA256=$((Get-FileHash $fs[0].FullName -Algorithm SHA256).Hash)"
Write-Warning 'CANDIDATE ONLY: inspect post-route STA before loading to SRAM. No hardware programming performed.'
