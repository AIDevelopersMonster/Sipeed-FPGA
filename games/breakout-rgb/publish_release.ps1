#requires -Version 7.0
<#
KonSol RetroStation Breakout RGB v0.1.0
Offline identity verification by default; only -Publish creates a GitHub prerelease.
Requires GitHub CLI (gh), access to the exact operator-tested .fs on disk.
Never programs FPGA SRAM or Flash.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Bitstream,
    [switch]$Publish
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = 'AIDevelopersMonster/Sipeed-FPGA'
$tag = 'konsol-breakout-rgb-v0.1.0'
$expectedName = 'pikosol_breakout_rgb_nano9k.fs'
$expected = '4CF80DBD008B0D41D4316BF63DB952190C03940A4FFB1FFC00CAB09210AE8789'
$fs = (Resolve-Path -LiteralPath $Bitstream -ErrorAction Stop).Path

if ((Split-Path -Leaf $fs) -cne $expectedName) {
    throw "STOP: Wrong file name. Expected $expectedName"
}
$size = (Get-Item -LiteralPath $fs).Length
if ($size -lt 10000 -or $size -gt 12582912) {
    throw "STOP: Unusual bitstream size ($size bytes)"
}
$actual = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($actual -cne $expected) {
    throw "STOP: SHA-256 mismatch. Expected=$expected Actual=$actual"
}
Write-Host "RS003_LOCAL_SHA256_PASS: $actual ($size bytes)" -ForegroundColor Green

if (-not $Publish) {
    Write-Host 'RS003_DRY_RUN: No GitHub release created. Use -Publish to upload.'
    return
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not installed / not in PATH'
}
& gh auth status
if ($LASTEXITCODE -ne 0) { throw 'GitHub CLI not authenticated' }
& gh release view $tag --repo $repo 2>$null
if ($LASTEXITCODE -eq 0) { throw "STOP: Existing release $tag. Refusing overwrite." }

$notes = Join-Path $PSScriptRoot 'RELEASE_NOTES_v0.1.0.md'
if (-not (Test-Path -LiteralPath $notes -PathType Leaf)) {
    throw "Release notes missing: $notes"
}
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("rs003_" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $manifest = Join-Path $tmp 'SHA256SUMS.txt'
    Set-Content -LiteralPath $manifest -Value ($expected.ToLowerInvariant() + '  ' + $expectedName) -Encoding ascii
    Write-Host "Publishing prerelease tag $tag (main) ... "
    & gh release create $tag $fs $manifest --repo $repo --target main --prerelease --title 'KonSol RetroStation BREAKOUT RGB v0.1.0 | Tang Nano 9K' --notes-file $notes
    if ($LASTEXITCODE -ne 0) { throw 'gh release create failed; inspect GitHub before retrying' }

    $verify = Join-Path $tmp 'verify'
    New-Item -ItemType Directory -Force -Path $verify | Out-Null
    & gh release download $tag --repo $repo --pattern $expectedName --dir $verify
    if ($LASTEXITCODE -ne 0) { throw 'Release exists, but binary re-download failed' }
    $remote = (Get-FileHash -LiteralPath (Join-Path $verify $expectedName) -Algorithm SHA256).Hash
    if ($remote -cne $expected) { throw "REMOTE_SHA256_FAIL: $remote" }
    Write-Host "RS003_REMOTE_RELEASE_SHA256_PASS: $remote" -ForegroundColor Green
    Write-Host "RS003_RELEASE_PUBLISHED: https://github.com/$repo/releases/tag/$tag" -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
