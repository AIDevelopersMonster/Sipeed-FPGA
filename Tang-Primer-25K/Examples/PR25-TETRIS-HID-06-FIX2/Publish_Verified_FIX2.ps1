#Requires -Version 7.0
<#
Publish ALREADY UNPACKED, operator-confirmed PR25 TETRIS HID 06 FIX2 sources
and the existing confirmed .fs via the user's git and gh CLIs, without rebuilding.
SourceDir defaults to the folder used in the earlier operator PowerShell commands.
No FPGA programming. Only explicit GitHub writes when -Publish is given.
#>
[CmdletBinding()]
param(
  [string]$SourceDir = (Join-Path $env:TEMP 'PR25_TETRIS_HID_06_Package'),
  [string]$Fs,
  [string]$RepositoryRoot = 'C:\GitHub\Sipeed-FPGA',
  [string]$Tag = 'pr25-tetris-hid-06-fix2-board-pass',
  [switch]$Publish
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$relative='Tang-Primer-25K/Examples/PR25-TETRIS-HID-06-FIX2'
$target=Join-Path $RepositoryRoot $relative
if (!(Test-Path -LiteralPath $SourceDir -PathType Container)) { throw "Previously used unpack folder not found: $SourceDir. Provide -SourceDir if FIX2 was unpacked elsewhere." }
if ([string]::IsNullOrWhiteSpace($Fs)) {
  $buildDir = Join-Path $env:TEMP 'PR25_TETRIS_HID_06'
  if (!(Test-Path -LiteralPath $buildDir -PathType Container)) { throw "Build folder not found: $buildDir. Provide -Fs for the exact tested image." }
  $images = @(Get-ChildItem -LiteralPath $buildDir -Filter '*.fs' -File -Recurse)
  if ($images.Count -ne 1) {
    $images | Select-Object FullName,Length,LastWriteTime | Format-Table -AutoSize
    throw "Found $($images.Count) .fs files in $buildDir; refusing an arbitrary choice. Provide -Fs."
  }
  $Fs = $images[0].FullName
}
if (!(Test-Path -LiteralPath $Fs -PathType Leaf)) { throw "Working .fs not found: $Fs" }
if ([IO.Path]::GetExtension($Fs).ToLowerInvariant() -ne '.fs') { throw 'The chosen bitstream must have .fs extension.' }
$git=(Get-Command git -ErrorAction Stop).Source
$gh=(Get-Command gh -ErrorAction Stop).Source
if (!(Test-Path -LiteralPath (Join-Path $RepositoryRoot '.git'))) { throw "Not a Git checkout: $RepositoryRoot" }
$origin=(& $git -C $RepositoryRoot remote get-url origin | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $origin -notmatch '(^|[:/])AIDevelopersMonster/Sipeed-FPGA(\.git)?$') {
  throw "Unexpected Git origin: $origin"
}
$branch=(& $git -C $RepositoryRoot branch --show-current | Out-String).Trim()
if ($branch -ne 'main') { throw "Expected main branch, got: $branch" }
$dirty=@(& $git -C $RepositoryRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw 'Git working tree has local changes; commit/back up separately first.' }
$fsInfo=Get-Item -LiteralPath $Fs
if ($fsInfo.Length -lt 100000) { throw "Suspiciously small FPGA bitstream: $($fsInfo.Length) bytes" }
$fsHash=(Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash
Write-Host "ALREADY UNPACKED SOURCE: $SourceDir"
Write-Host "WORKING FS: $Fs"
Write-Host "FS SHA256: $fsHash"
Write-Host 'Confirm that the chosen .fs is EXACTLY the one tested with VIDEO, USB HID and gameplay PASS.'
if (!$Publish) {
  Write-Host 'DRY RUN: no GitHub writes or source changes. To publish, repeat with -Publish.'
  return
}
$confirmation=Read-Host "Type PUBLISH to attest this .fs was actually BOARD PASS and publish"
if ($confirmation -cne 'PUBLISH') { throw 'Publication cancelled; no changes made.' }
$stage = $SourceDir
  $allFiles=@(Get-ChildItem -LiteralPath $stage -Recurse -File)
  foreach ($name in @('Build_Tetris_HID06.ps1','lab_top_tetris_hid06.sv','tetris_engine.sv')) {
    if (@($allFiles | Where-Object { $_.Name -eq $name }).Count -ne 1) {
      throw "Expected exactly one $name in the confirmed FIX2 ZIP."
    }
  }
  $allowed=@('.ps1','.sv','.v','.cst','.sdc','.mem','.vh','.svh','.md','.txt','.tcl','.json','.gprj','.gitignore')
  foreach ($file in $allFiles) {
    if ($file.Extension.ToLowerInvariant() -notin $allowed -and $file.Name -ne '.gitignore') {
      throw "Unexpected file in ZIP; refuse to mirror without inspection: $($file.FullName)"
    }
    if ($file.FullName -match '[\\/](_vendor|impl|pnr|\.git)[\\/]') {
      throw "Unexpected generated/vendor subtree in source ZIP: $($file.FullName)"
    }
  }
  $sourceBase=$stage
  # Common single-directory ZIP layout.
  if (@(Get-ChildItem -LiteralPath $stage -Directory).Count -eq 1 -and
      @(Get-ChildItem -LiteralPath $stage -File).Count -eq 0) {
    $sourceBase=@(Get-ChildItem -LiteralPath $stage -Directory)[0].FullName
  }
  $sourceFiles=@(Get-ChildItem -LiteralPath $sourceBase -Recurse -File)
  $sourceTarget=Join-Path $target 'source'
  $prefix=[IO.Path]::GetFullPath($sourceBase).TrimEnd('\')+'\'
  foreach($file in $sourceFiles) {
    $rel=$file.FullName.Substring($prefix.Length)
    $dest=Join-Path $sourceTarget $rel
    if (Test-Path -LiteralPath $dest) {
      throw "Destination already contains $rel; no automatic overwrite. Review repository first."
    }
  }
  foreach($file in $sourceFiles) {
    $rel=$file.FullName.Substring($prefix.Length)
    $dest=Join-Path $sourceTarget $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
    Copy-Item -LiteralPath $file.FullName -Destination $dest
  }
  $manifest=[ordered]@{
    experiment='PR25-TETRIS-HID-06-FIX2'
    acceptance='BOARD VIDEO + USB HID + TETRIS GAMEPLAY PASS (operator)'
    tested_board='Tang Primer 25K + Dock / GW5A-25A'
    source_directory=$SourceDir
    bitstream_filename=[IO.Path]::GetFileName($Fs)
    bitstream_sha256=$fsHash
    bitstream_size_bytes=$fsInfo.Length
    flashed_to_nonvolatile_flash=$false
    video='https://youtube.com/shorts/G0fNR4Szqfw'
    note='No rebuild was done by this publishing tool. Operator selected previously tested .fs.'
  }
  $manifestPath=Join-Path $target 'BOARD_PASS_MANIFEST.json'
  [IO.File]::WriteAllText($manifestPath,($manifest|ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
  & $git -C $RepositoryRoot add -- $relative
  if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
  & $git -C $RepositoryRoot diff --cached --stat
  & $git -C $RepositoryRoot commit -m 'feat(pr25): publish operator-verified Tetris HID FIX2 sources'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
  & $git -C $RepositoryRoot push origin main
  if ($LASTEXITCODE -ne 0) { throw 'git push failed; source committed locally, release not attempted' }
  & $gh release view $Tag --repo AIDevelopersMonster/Sipeed-FPGA 2>$null | Out-Null
  if ($LASTEXITCODE -eq 0) { throw "GitHub release $Tag already exists; refuse overwriting release asset." }
  & $gh release create $Tag --repo AIDevelopersMonster/Sipeed-FPGA --target main --title 'Tang Primer 25K Tetris USB HID FIX2 — BOARD PASS' --notes "Operator-verified Tetris: USB HID full controls, DVI/HDMI video, BRAM only. SHA256 of original .fs: $fsHash. Sources in $relative. No rebuild during publication. Video: https://youtube.com/shorts/G0fNR4Szqfw" $Fs
  if ($LASTEXITCODE -ne 0) { throw 'Release creation/asset upload failed; Git sources were pushed. Do not assume .fs is published.' }
  Write-Host "PUBLISHED: https://github.com/AIDevelopersMonster/Sipeed-FPGA/releases/tag/$Tag"
  Write-Host "SHA256: $fsHash"

