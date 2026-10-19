# Read-only file hash check against MANIFEST.sha256.
$ErrorActionPreference='Stop'
$Root = Split-Path -Parent $PSScriptRoot
$Manifest = Join-Path $Root 'MANIFEST.sha256'
if (-not (Test-Path -LiteralPath $Manifest)) { throw 'MANIFEST.sha256 not found' }
$count = 0
foreach ($line in (Get-Content -LiteralPath $Manifest)) {
  if ($line -match '^([0-9a-f]{64})  (.+)$') {
    $path = Join-Path $Root ($Matches[2].Replace('/', '\'))
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing file $path" }
    $sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($sha -ne $Matches[1]) { throw "SHA256 mismatch: $path" }
    $count++
  } else { throw "Bad manifest line: $line" }
}
Write-Host "Integrity PASS: $count files" 
