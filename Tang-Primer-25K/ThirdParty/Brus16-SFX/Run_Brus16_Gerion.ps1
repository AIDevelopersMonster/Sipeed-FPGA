#Requires -Version 7.0
# BRUS16-SFX: download verified official TP25K archive and optionally program
# Gerion into VOLATILE FPGA SRAM. This script NEVER writes external Flash.
# Upstream release: https://github.com/Papr1ka/brus16/releases/tag/sfx
[CmdletBinding()]
param(
    [switch]$Program,
    [switch]$ForceDownload,
    [string]$Game = 'gerion',
    [int]$CableIndex = 1,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($Game -notmatch '^[A-Za-z0-9_-]+$') {
    throw 'Game name must contain letters, numbers, underscores or hyphens only.'
}
$sourceUri = 'https://github.com/Papr1ka/brus16/releases/download/sfx/tp25k.zip'
$officialSha256 = 'a8c0e4e096656b89d8b74c4929abbe8d601da996e1ac6d2b1f78480a8a270e69'
$officialSize = [int64]4214200

$firmwareDir = Join-Path $PSScriptRoot 'firmware'
$evidenceDir = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $firmwareDir, $evidenceDir | Out-Null
$archivePath = Join-Path $firmwareDir 'tp25k_sfx.zip'
$logPath = Join-Path $evidenceDir ('BRUS16_SFX_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
Start-Transcript -LiteralPath $logPath | Out-Null

try {
    Write-Host 'Brus-16 SFX Tang Primer 25K: original-author Gerion experiment'
    Write-Host 'Release: Papr1ka/brus16 tag sfx, 2026-07-13'
    Write-Host "Firmware archive: $archivePath"
    Write-Host 'IMPORTANT: SRAM ONLY. FLASH / BL616 / SD CARD WILL NOT BE MODIFIED.'

    if ($ForceDownload -or !(Test-Path -LiteralPath $archivePath)) {
        $partialPath = "$archivePath.part"
        if (Test-Path -LiteralPath $partialPath) {
            Remove-Item -LiteralPath $partialPath -Force
        }
        Write-Host "Downloading pinned release: $sourceUri"
        Invoke-WebRequest -Uri $sourceUri -OutFile $partialPath
        Move-Item -LiteralPath $partialPath -Destination $archivePath -Force
    }

    $archiveSize = (Get-Item -LiteralPath $archivePath).Length
    $archiveSha256 = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "ZIP size:   $archiveSize"
    Write-Host "ZIP SHA256: $archiveSha256"

    if ($archiveSize -ne $officialSize) {
        throw "ZIP size mismatch (expected $officialSize). Stop: do not program."
    }
    if ($archiveSha256 -ne $officialSha256) {
        throw "ZIP SHA256 mismatch with official GitHub Release asset digest. Stop."
    }
    Write-Host 'PASS: ZIP matches official GitHub Release size and SHA256.'

    Add-Type -AssemblyName System.IO.Compression.ZipFile
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        $allFiles = @($zip.Entries | Where-Object { $_.Name.Length -gt 0 })
        Write-Host ''
        Write-Host 'ARCHIVE CONTENTS:'
        foreach ($item in $allFiles) {
            Write-Host ('  {0}   {1} bytes' -f $item.FullName, $item.Length)
        }
        Write-Host ''

        $fsEntries = @($allFiles | Where-Object { $_.Name -match '(?i)\.fs$' })
        $candidates = @($fsEntries | Where-Object {
            $_.FullName.IndexOf($Game, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        })

        if ($candidates.Count -ne 1) {
            Write-Host "Candidates for '$Game': $($candidates.Count)"
            if ($fsEntries.Count -eq 0) {
                Write-Host 'No direct Gowin .fs files found. ZIP may have a different layout; stop safely.'
            } else {
                Write-Host 'Gowin .fs files found:'
                $fsEntries | ForEach-Object { Write-Host "  $($_.FullName)" }
            }
            throw "Cannot unambiguously select $Game .fs. Do not guess a firmware file."
        }

        $selected = $candidates[0]
        if ($selected.Length -lt 100000 -or $selected.Length -gt 30000000) {
            throw "Selected .fs length is outside the safety range: $($selected.Length)"
        }
        $fsPath = Join-Path $firmwareDir ($Game.ToLowerInvariant() + '.fs')
        [System.IO.Compression.ZipFileExtensions]::ExtractToFile($selected, $fsPath, $true)
        Write-Host "Selected ZIP entry: $($selected.FullName)"
    }
    finally {
        $zip.Dispose()
    }

    $fsInfo = Get-Item -LiteralPath $fsPath
    $fsSha256 = (Get-FileHash -LiteralPath $fsPath -Algorithm SHA256).Hash.ToLowerInvariant()
    Write-Host "FS: $fsPath"
    Write-Host "FS size: $($fsInfo.Length)"
    Write-Host "FS SHA256: $fsSha256"

    $report = [ordered]@{
        project = 'Brus-16 TP25K HDMI sound sfx'
        source = $sourceUri
        source_tag = 'sfx'
        release_sha256 = $officialSha256
        zip_sha256 = $archiveSha256
        zip_size = $archiveSize
        zip_entry = $selected.FullName
        extracted_fs = $fsPath
        fs_size = $fsInfo.Length
        fs_sha256 = $fsSha256
        timestamp = (Get-Date).ToString('o')
        intended_target = 'Tang Primer 25K GW5A-25A / volatile FPGA SRAM'
        programming_requested = [bool]$Program
    }
    $manifestPath = Join-Path $evidenceDir ('BRUS16_' + $Game + '_MANIFEST.json')
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    Write-Host "Manifest: $manifestPath"

    if (-not $Program) {
        Write-Host 'INSPECT PASS: no FPGA programming performed.'
        Write-Host "After checking the entry, rerun with -Program to load $Game into SRAM."
    }
    else {
        if (!(Test-Path -LiteralPath $Programmer)) {
            throw "Gowin Programmer not found: $Programmer"
        }
        Write-Host 'PROGRAMMING: FPGA SRAM ONLY (--run 2). The original Flash is untouched.'
        Write-Host ('Target GW5A-25A, cable index {0}, file {1}' -f $CableIndex, $fsPath)
        & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fsPath
        $programExit = $LASTEXITCODE
        Write-Host "Programmer exit: $programExit"
        if ($programExit -ne 0) {
            throw "Gowin SRAM programming failed with exit code $programExit."
        }
        Write-Host 'SRAM programming command succeeded. VIDEO and AUDIO still require observation.'
        Write-Host 'The Gerion game may need input to begin playback: an image alone is NOT an AUDIO PASS.'
    }
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "Evidence log: $logPath"
}
