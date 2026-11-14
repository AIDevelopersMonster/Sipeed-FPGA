#Requires -Version 7.0
# PR25-13: preserve the exact observed WORKING .fs without rebuilding or programming FPGA.
# Default: local verified backup. -PublishRelease: additionally upload .fs using gh.
[CmdletBinding()]
param(
  [switch]$PublishRelease,
  [string]$BackupDirectory=(Join-Path $HOME 'Sipeed-FPGA-Verified-Backups')
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$src=Join-Path $root 'artifacts\a2600nano_tp25k_SDC50.fs'
$name='a2600nano_tp25k_SDC50.fs'
$expected='22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a'
$tag='tp25k-pr25-13-video-audio-20261115'
$repository='AIDevelopersMonster/Sipeed-FPGA'
if (!(Test-Path -LiteralPath $src)){throw "Working .fs not found: $src"}
$hash=(Get-FileHash -LiteralPath $src -Algorithm SHA256).Hash.ToLowerInvariant()
if ($hash -ne $expected){throw "Refusing backup: SHA256 mismatch $hash"}
$size=(Get-Item -LiteralPath $src).Length
if ($size -lt 100000){throw "Invalid .fs size: $size"}
New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$dst=Join-Path $BackupDirectory ("PR25-13_"+$expected.Substring(0,12)+"_"+$name)
if (Test-Path -LiteralPath $dst){
  $dstHash=(Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($dstHash -ne $expected){throw "Existing backup has different bytes: $dst"}
}else{
  Copy-Item -LiteralPath $src -Destination $dst
}
$check=(Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
if ($check -ne $expected){throw 'Backup copy verification failed'}
$receipt=Join-Path $BackupDirectory ('PR25-13_'+$expected.Substring(0,12)+'_receipt.txt')
@(
  'BOARD PR25-13: VIDEO PASS (animated details on splash), AUDIO PASS (8-bit style melody)'
  'FPGA Tang Primer 25K, GW5A-25A, volatile SRAM'
  "SOURCE: $src"
  "COPY: $dst"
  "BYTES: $size"
  "SHA256: $expected"
  ('CHECKED_UTC: '+(Get-Date).ToUniversalTime().ToString('o'))
  'No hardware programming/build performed by this script.'
) | Set-Content -LiteralPath $receipt -Encoding utf8
Write-Host "BACKUP VERIFIED: $dst"
Write-Host "SHA256: $check"
Write-Host "RECEIPT: $receipt"
if (!$PublishRelease){
  Write-Host 'GITHUB RELEASE NOT UPLOADED. To publish later use -PublishRelease.'
  return
}
$gh=Get-Command gh -ErrorAction SilentlyContinue
if (!$gh){throw 'GitHub CLI gh not installed; local backup already verified'}
& gh auth status
if ($LASTEXITCODE -ne 0){throw 'gh authentication failed; local backup already verified'}
$exists=$false
& gh release view $tag --repo $repository *> $null
if ($LASTEXITCODE -eq 0){$exists=$true}
if ($exists){
  $assetNames=@(& gh release view $tag --repo $repository --json assets --jq '.assets[].name')
  if ($LASTEXITCODE -ne 0){throw 'Cannot inspect existing release; will not overwrite'}
  if (@($assetNames | Where-Object {$_ -eq $name}).Count -gt 0){
    throw "GitHub release $tag already has asset $name; refusing overwrite. Local copy remains safe."
  }
  & gh release upload $tag $dst --repo $repository
}else{
  $notes=@(
    'PR25-13: Verified on Tang Primer 25K (GW5A-25A), FPGA SRAM only.'
    'Observed splash animation of individual details; not proof of full gameplay.'
    'Audible musical/chiptune-style soundtrack reminiscent of 8-bit consoles.'
    "SHA256: $expected"
    'Gowin 1.9.9Beta-4. Setup/Hold global violation counters = 0/0.'
    'TA1123/TA1117 clock-model warnings remain; production timing approval pending.'
    'Firmware is an independent experimental build, not the vendor Golden v2.5.'
  ) -join [Environment]::NewLine
  $noteFile=Join-Path $BackupDirectory ('PR25-13_'+$expected.Substring(0,12)+'_release_notes.txt')
  $notes | Set-Content -LiteralPath $noteFile -Encoding utf8
  & gh release create $tag $dst --repo $repository --target main --title 'PR25-13 Tang Primer 25K - video + 8-bit-style audio PASS' --notes-file $noteFile
}
if ($LASTEXITCODE -ne 0){throw "GitHub release upload failed. Local backup remains verified at $dst"}
Write-Host "GITHUB RELEASE UPLOADED: https://github.com/$repository/releases/tag/$tag"
Write-Host "SHA256 VERIFY: $expected"
