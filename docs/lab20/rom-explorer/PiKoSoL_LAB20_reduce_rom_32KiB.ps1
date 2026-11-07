# PiKoSoL LAB-20.4 — produce the canonical 32 KiB ROM from the verified 128 KiB read-only dump.
# No serial device is opened, and no FPGA memory is changed.
[CmdletBinding()]
param(
  [string]$InputFile = (Join-Path $PSScriptRoot 'captures\PiKoSoL_LAB20_ROM_128KiB.bin'),
  [string]$OutputFile = (Join-Path $PSScriptRoot 'captures\PiKoSoL_LAB20_ROM_32KiB.bin')
)
$ErrorActionPreference = 'Stop'
$ExpectedFull = 'FAC8E6E6F39A22E2995DE54C271646687D86AD9802E884B848BCF5B6EC4EDB65'
$ExpectedCanonical = '3347BE74E9716744949E572229345C3EA9E74F1740001408B934C0D85C79C5BC'
$Period = 32768
$Windows = 4

$FullInput = [System.IO.Path]::GetFullPath($InputFile)
$FullOutput = [System.IO.Path]::GetFullPath($OutputFile)
if ($FullInput -eq $FullOutput) { throw 'InputFile and OutputFile must differ.' }
if (-not (Test-Path -LiteralPath $FullInput -PathType Leaf)) { throw "Input file not found: $FullInput" }
$Bytes = [System.IO.File]::ReadAllBytes($FullInput)
if ($Bytes.Length -ne ($Period * $Windows)) { throw "Expected 131072 bytes, found $($Bytes.Length)." }
$GotFullHash = (Get-FileHash -LiteralPath $FullInput -Algorithm SHA256).Hash
if ($GotFullHash -ne $ExpectedFull) { throw "Source checksum mismatch: $GotFullHash" }

$Canonical = New-Object byte[] $Period
[System.Array]::Copy($Bytes, 0, $Canonical, 0, $Period)
for ($bank = 1; $bank -lt $Windows; $bank++) {
  $base = $bank * $Period
  for ($i = 0; $i -lt $Period; $i++) {
    if ($Bytes[$base + $i] -ne $Canonical[$i]) {
      throw ('MIRROR MISMATCH in window {0} at address 0x{1:X8}' -f $bank, ($base + $i))
    }
  }
}
$CanonHash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($Canonical))
if ($CanonHash -ne $ExpectedCanonical) { throw "Canonical checksum mismatch: $CanonHash" }
if (Test-Path -LiteralPath $FullOutput) {
  $Existing = [System.IO.File]::ReadAllBytes($FullOutput)
  if ($Existing.Length -ne $Period -or (Get-FileHash -LiteralPath $FullOutput -Algorithm SHA256).Hash -ne $ExpectedCanonical) {
    throw "Existing output differs from verified canonical image: $FullOutput"
  }
  Write-Host 'PASS: Existing 32 KiB file is identical; no rewrite needed.'
} else {
  $Parent = [System.IO.Path]::GetDirectoryName($FullOutput)
  if (-not (Test-Path -LiteralPath $Parent)) { New-Item -ItemType Directory -Path $Parent -Force | Out-Null }
  [System.IO.File]::WriteAllBytes($FullOutput, $Canonical)
}
Write-Host 'ROM REDUCTION PASS'
Write-Host ('Mirrors: {0} x {1} bytes = {2} bytes (all identical)' -f $Windows, $Period, $Bytes.Length)
Write-Host ('SHA256 128KiB: {0}' -f $GotFullHash)
Write-Host ('SHA256  32KiB: {0}' -f $CanonHash)
Write-Host ('Output: {0}' -f $FullOutput)
