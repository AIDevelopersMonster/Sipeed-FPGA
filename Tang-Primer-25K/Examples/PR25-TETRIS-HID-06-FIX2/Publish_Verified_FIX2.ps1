#Requires -Version 7.0
<#
Publish Tetris FIX2 from the EXACT original operator build folders.
No FPGA programming, no rebuild, no new checkout or temporary folder.
Sources go to this project in Sipeed-FPGA, verified .fs to GitHub Releases.
#>
[CmdletBinding()]
param(
  [string]$SourceDir = (Join-Path $env:TEMP 'PR25_TETRIS_HID_06_Package'),
  [string]$Fs = (Join-Path $env:TEMP 'PR25_TETRIS_HID_06\impl\pnr\pr25_tetris_hid06.fs'),
  [string]$RepoRoot = 'C:\GitHub\Sipeed-FPGA',
  [string]$Tag = 'pr25-tetris-hid-06-fix2-board-pass',
  [switch]$Publish
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = 'AIDevelopersMonster/Sipeed-FPGA'
$rel = 'Tang-Primer-25K/Examples/PR25-TETRIS-HID-06-FIX2'
$target = Join-Path $RepoRoot $rel
$sourceTarget = Join-Path $target 'source'
if (!(Test-Path -LiteralPath $SourceDir -PathType Container)) { throw "Unpacked FIX2 sources missing: $SourceDir. Use -SourceDir with their actual directory." }
if (!(Test-Path -LiteralPath $Fs -PathType Leaf)) { throw "Tested .fs missing: $Fs" }
if ([IO.Path]::GetExtension($Fs).ToLowerInvariant() -ne '.fs') { throw "Expected an .fs file" }
$fsItem = Get-Item -LiteralPath $Fs
if ($fsItem.Length -lt 100000) { throw "Unexpected .fs length $($fsItem.Length)" }
$fsHash = (Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash
$git = (Get-Command git -ErrorAction Stop).Source
$gh = (Get-Command gh -ErrorAction Stop).Source
if (!(Test-Path -LiteralPath (Join-Path $RepoRoot '.git'))) { throw "No git checkout: $RepoRoot" }
$remote = (& $git -C $RepoRoot remote get-url origin | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $remote -notmatch '(^|[:/])AIDevelopersMonster/Sipeed-FPGA(\.git)?$') { throw "Wrong origin: $remote" }
$branch = (& $git -C $RepoRoot branch --show-current | Out-String).Trim()
if ($branch -ne 'main') { throw "Expected branch main, got $branch" }
$dirty = @(& $git -C $RepoRoot status --porcelain)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) { throw "Git checkout has uncommitted files; do not mix them with this verified release." }

$required = @('Build_Tetris_HID06.ps1','lab_top_tetris_hid06.sv','tetris_engine.sv')
$all = @(Get-ChildItem -LiteralPath $SourceDir -Recurse -File)
foreach ($name in $required) {
  if (@($all | Where-Object { $_.Name -eq $name }).Count -ne 1) { throw "Expected exactly one $name in $SourceDir" }
}
$requiredDirs = @($all | Where-Object { $_.Name -in $required } | ForEach-Object { $_.DirectoryName } | Select-Object -Unique)
if ($requiredDirs.Count -ne 1) { throw "Tetris source files are in different folders; choose the exact FIX2 directory." }
$actualSource = $requiredDirs[0]
$sourceFiles = @(Get-ChildItem -LiteralPath $actualSource -Recurse -File)
$allowed = @('.ps1','.sv','.v','.cst','.sdc','.mem','.vh','.svh','.tcl','.json','.gprj','.md','.txt')
$prefix = [IO.Path]::GetFullPath($actualSource).TrimEnd('\') + '\'
foreach ($file in $sourceFiles) {
  if ($file.Extension.ToLowerInvariant() -notin $allowed) { throw "Unexpected non-source file: $($file.FullName)" }
  if ($file.FullName -match '[\\/](_vendor|impl|pnr|\.git)[\\/]') { throw "Generated/vendor files inside source: $($file.FullName)" }
  $relativePath = $file.FullName.Substring($prefix.Length)
  $destination = Join-Path $sourceTarget $relativePath
  if (Test-Path -LiteralPath $destination) {
    $h = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    $existing = (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash
    if ($h -ne $existing) { throw "Would overwrite a different source: $destination" }
  }
}
Write-Host "Source directory: $actualSource"
Write-Host "Source files: $($sourceFiles.Count)"
Write-Host "Existing working FS: $Fs"
Write-Host "FS SHA256: $fsHash"
if (!$Publish) { Write-Host "PREVIEW ONLY. Add -Publish to send sources and original .fs to GitHub."; return }

$confirm = Read-Host "Confirm this is the tested FIX2 source and .fs. Type FIX2"
if ($confirm -cne 'FIX2') { throw 'Cancelled. No repository changes.' }
foreach ($file in $sourceFiles) {
  $relativePath = $file.FullName.Substring($prefix.Length)
  $destination = Join-Path $sourceTarget $relativePath
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
  if (!(Test-Path -LiteralPath $destination)) { Copy-Item -LiteralPath $file.FullName -Destination $destination }
}
$sourceHashes = @(foreach ($file in $sourceFiles) {
  [ordered]@{ file = $file.FullName.Substring($prefix.Length).Replace('\','/'); sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash }
})
$manifest = [ordered]@{
  experiment='PR25-TETRIS-HID-06-FIX2'
  source='operator-confirmed FIX2 extracted sources, no rebuild'
  source_files=$sourceHashes
  fs_filename=$fsItem.Name
  fs_size=$fsItem.Length
  fs_sha256=$fsHash
  hardware='Tang Primer 25K + Dock GW5A-25A'
  acceptance='BOARD PASS: Tetris gameplay, USB HID controls, HDMI video'
  memory='BRAM only'
  programming='FPGA SRAM only, no Flash'
  video='https://youtube.com/shorts/G0fNR4Szqfw'
}
[IO.File]::WriteAllText((Join-Path $target 'BOARD_PASS_MANIFEST.json'),($manifest | ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
& $git -C $RepoRoot add -- $rel
if ($LASTEXITCODE -ne 0) { throw 'git add failed' }
& $git -C $RepoRoot diff --cached --quiet
if ($LASTEXITCODE -eq 1) {
  & $git -C $RepoRoot commit -m 'release(pr25): save tested Tetris HID FIX2 sources and SHA256'
  if ($LASTEXITCODE -ne 0) { throw 'git commit failed' }
}
& $git -C $RepoRoot push origin main
if ($LASTEXITCODE -ne 0) { throw 'git push failed; Release not attempted' }
& $gh release create $Tag $Fs --repo $repo --target main --title 'Tang Primer 25K Tetris USB HID FIX2 - BOARD PASS' --notes "Operator-verified Tetris, full USB keyboard control and HDMI video, BRAM-only. FS SHA256: $fsHash. Sources: $rel. Video: https://youtube.com/shorts/G0fNR4Szqfw"
if ($LASTEXITCODE -ne 0) { throw 'Release upload failed: check github.com Releases before cleaning local directories' }
Write-Host "Published source: https://github.com/$repo/tree/main/$rel"
Write-Host "Published firmware: https://github.com/$repo/releases/tag/$Tag"
Write-Host "FS SHA256: $fsHash"
