#Requires -Version 7.0
# Publish exactly one BOARD VIDEO PASS KonSol example into its Examples folder.
# NO releases, NO git pull/checkout/reset/clean, NO FPGA/Flash writes.
[CmdletBinding()]
param(
    [string]$PackageDir = "$env:TEMP\PR25_KonSol_Package",
    [string]$FsFile = "$env:TEMP\PR25_KonSol_LocalTrial\impl\pnr\pr25_konsol_trial.fs",
    [string]$Repository = 'AIDevelopersMonster/Sipeed-FPGA',
    [string]$Branch = 'main'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (!(Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI gh is required: install it and run gh auth login'
}
$root = 'Tang-Primer-25K/Examples/PR25-KonSol-DVI'
$rtl = Join-Path $PackageDir 'lab_top_konsol.sv'
$build = Join-Path $PackageDir 'Build_KonSol_Trial.ps1'
foreach ($f in @($rtl, $build, $FsFile)) {
    if (!(Test-Path -LiteralPath $f -PathType Leaf)) { throw "Missing required LOCAL file: $f" }
}
if ((Get-Item -LiteralPath $FsFile).Length -lt 100000) { throw 'FS is unexpectedly small' }
$hash = (Get-FileHash -LiteralPath $FsFile -Algorithm SHA256).Hash.ToLowerInvariant()
$bytes = (Get-Item -LiteralPath $FsFile).Length
Write-Host "BINARY: $FsFile"
Write-Host "SIZE: $bytes"
Write-Host "SHA256: $hash"
Write-Host 'Destination: examples folder only; no GitHub Releases'

# GitHub contents API: create-only (no SHA); existing file leads to error.
# Temp JSON is outside repository and removed even on error.
function PublishFile([string]$localPath, [string]$relativePath, [string]$message) {
    $uri = "/repos/$Repository/contents/$root/$relativePath"
    $body = [ordered]@{
        message = $message
        content = [Convert]::ToBase64String([IO.File]::ReadAllBytes($localPath))
        branch = $Branch
    }
    $inputPath = Join-Path $env:TEMP ("pr25_gh_upload_" + [Guid]::NewGuid().ToString('N') + ".json")
    try {
        [IO.File]::WriteAllText($inputPath, ($body | ConvertTo-Json -Depth 5 -Compress), [Text.UTF8Encoding]::new($false))
        & gh api --method PUT -H 'Accept: application/vnd.github+json' $uri --input $inputPath | Out-Null
        if ($LASTEXITCODE -ne 0) { throw "GitHub upload failed for $relativePath" }
        Write-Host "UPLOADED: $root/$relativePath"
    }
    finally {
        Remove-Item -LiteralPath $inputPath -Force -ErrorAction SilentlyContinue
    }
}

# Publish the original, physically verified trial sources first.
PublishFile $rtl 'rtl/lab_top_konsol.sv' 'pr25-konsol: save verified local trial RGB generator'
PublishFile $build 'build/Build_KonSol_Trial.ps1' 'pr25-konsol: save original trial build procedure'
PublishFile $FsFile 'fs/pr25_konsol_trial.fs' 'pr25-konsol: add board-video-pass SRAM bitstream'

$hashPath = Join-Path $env:TEMP ("pr25_konsol_sha_" + [Guid]::NewGuid().ToString('N') + ".txt")
try {
    [IO.File]::WriteAllText($hashPath, "$hash  pr25_konsol_trial.fs" + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    PublishFile $hashPath 'fs/sha256.txt' 'pr25-konsol: record SHA256 of verified bitstream'
}
finally { Remove-Item -LiteralPath $hashPath -Force -ErrorAction SilentlyContinue }
Write-Host 'DONE: the small working example is in Examples/PR25-KonSol-DVI, not a release.'
