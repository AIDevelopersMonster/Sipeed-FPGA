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
    $expected = $Matches[1]
    if ($sha -ne $expected) {
      $rel = $Matches[2]
      if ($rel -notmatch '(?i)(^\.gitignore$|\.(?:md|txt|ps1|py|v|sv|vh|s|hex|json|tcl|cst|sdc|gprj|html|js|css|csv|yaml|yml)$)') {
        throw "SHA256 mismatch: $path"
      }

      $utf8 = [System.Text.UTF8Encoding]::new($false, $true)
      try {
        $content = $utf8.GetString([System.IO.File]::ReadAllBytes($path))
      } catch {
        throw "Invalid UTF-8 or SHA256 mismatch: $path"
      }

      if (-not $content.Contains("`r`n")) {
        throw "SHA256 mismatch: $path"
      }

      $normalized = $content.Replace("`r`n", "`n")
      $bytes = $utf8.GetBytes($normalized)
      $lfSha = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
      ).ToLowerInvariant()

      if ($lfSha -ne $expected) {
        throw "SHA256 mismatch: $path"
      }

      Write-Host "CRLF_OK: $rel"
    }
    $count++
  } else { throw "Bad manifest line: $line" }
}
Write-Host "Integrity PASS: $count files" 
