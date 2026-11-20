#requires -Version 7.0
<#
Download/verify the exact tested PiKoSoL TP20 package from GitHub.
Default: download and SHA256 check only (no COM, no FPGA, no Flash).
Optional -BoardTest: program the exact .fs to FPGA SRAM, then upload monitor
via the original host_console.py (the temporary PC> console remains open).
Never loads FPGA Flash.
#>
[CmdletBinding()]
param(
    [string]$Repository = 'AIDevelopersMonster/Sipeed-FPGA',
    [string]$Branch = 'main',
    [string]$Destination = "$env:USERPROFILE\Downloads\PiKoSoL_TP20_From_GitHub",
    [switch]$BoardTest,
    [string]$Port = 'COM10'
)
$ErrorActionPreference = 'Stop'
$base = 'Tang-Primer-20K/Examples/PR20-03-PiKoSoL-KonSol'
$uri = "https://raw.githubusercontent.com/$Repository/$Branch/$base"
$stage = "$Destination.download-in-progress"
if (Test-Path -LiteralPath $Destination) {
    throw "Destination already exists. Refusing to replace working files: $Destination"
}
if (Test-Path -LiteralPath $stage) {
    Write-Host "RESUMING PREVIOUS INCOMPLETE DOWNLOAD: $stage" -ForegroundColor Yellow
} else {
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
}
function Fetch-One([string]$relative, [string]$target) {
    $name = ($relative -split '/')[-1]
    $url = "$uri/$relative"
    $parent = Split-Path -Parent $target
    if (!(Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory $parent -Force | Out-Null }
    Write-Host "GET $relative"
    Invoke-WebRequest -Uri $url -OutFile $target -MaximumRedirection 5 -TimeoutSec 120
}
Fetch-One 'working-manifest.json' (Join-Path $stage 'working-manifest.json')
$manifest = Get-Content -LiteralPath (Join-Path $stage 'working-manifest.json') -Raw | ConvertFrom-Json
if ($manifest.schema -ne 1 -or $manifest.fpga_git_blob_sha1 -ne '5bb54a84311a62e1b0aadd11671c399561838b24') {
    throw 'Unexpected TP20 manifest or FPGA identity; download stopped.'
}
$files = @($manifest.files)
if ($files.Count -lt 10 -or $files.Count -gt 80) { throw "Unexpected manifest file count: $($files.Count)" }
$seen = @{}
foreach ($item in $files) {
    $rel = [string]$item.path
    if ($rel -notmatch '^[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*$' -or $rel.Contains('..')) {
        throw "Unsafe relative filename in manifest: $rel"
    }
    if ($seen.ContainsKey($rel)) { throw "Duplicate manifest path: $rel" }
    $seen[$rel] = $true
    $expected = ([string]$item.sha256).ToLowerInvariant()
    if ($expected -notmatch '^[a-f0-9]{64}$') { throw "Invalid SHA256 in manifest: $rel" }
    $target = Join-Path $stage $rel
    if (Test-Path -LiteralPath $target -PathType Leaf) {
        $oldSize = (Get-Item -LiteralPath $target).Length
        $oldHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($oldSize -eq [long]$item.bytes -and $oldHash -eq $expected) {
            Write-Host "SHA256 PASS (cached) $rel" -ForegroundColor Green
            continue
        }
    }
    Fetch-One $rel $target
    $realSize = (Get-Item -LiteralPath $target).Length
    $realHash = (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($realSize -ne [long]$item.bytes -or $realHash -ne $expected) {
        # Git normalized some original Windows CRLF text files to LF on commit.
        # Restore CRLF only when the transformed bytes match the PUBLISHED
        # manifest's original exact SHA256. Never alter .bin or .fs binaries.
        if ($rel -match '(?i)\.(cmd|ps1|py|md|txt|json)
}
# Preserve any existing download untouched. A new sync destination must be empty.
if (Test-Path -LiteralPath $Destination) {
    throw "Destination exists; refusing to replace or delete working files: $Destination"
}
Move-Item -LiteralPath $stage -Destination $Destination
Write-Host "DOWNLOAD VERIFIED: $Destination" -ForegroundColor Green
$root = $Destination
$fm = Join-Path $root 'FileManager'
$fw = Join-Path $root 'firmware'
$original = Join-Path $root 'TP20_PiKoSoL_Run.ps1'
# Original runner expects firmware files next to script:
# tp20k_System_picorv32.fs at root; monitor/demo below firmware;
# host_console.py under tools. Copy only local verified original .fs into required location.
$originalFs = Join-Path $fw 'tp20k_System_picorv32.fs'
$workingFs = Join-Path $root 'tp20k_System_picorv32.fs'
if (!(Test-Path -LiteralPath $workingFs)) { Copy-Item -LiteralPath $originalFs -Destination $workingFs }
Write-Host 'RUN CHECKS: use --root to point GUI to this downloaded baseline.' -ForegroundColor Cyan
& python (Join-Path $fm 'PiKoSoL_FileManager.py') --root $root --check
if ($LASTEXITCODE -ne 0) { throw 'Local original firmware verification failed' }
& python (Join-Path $fm 'PiKoSoL_FileManager.py') --root $root --check-apps
if ($LASTEXITCODE -ne 0) { throw 'Downloaded apps offline ABI check failed' }
if ($BoardTest) {
    Write-Host 'SRAM-only FPGA programming + serial monitor upload will start.' -ForegroundColor Yellow
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $original -BoardTest -Port $Port
    if ($LASTEXITCODE -ne 0) { throw 'BoardTest failed' }
}
Write-Host 'READY: To launch GUI, run:' -ForegroundColor Green
Write-Host ('python "' + (Join-Path $fm 'PiKoSoL_FileManager.py') + '" --root "' + $root + '"')
) {
            $rawBytes = [IO.File]::ReadAllBytes($target)
            $utf8 = [Text.UTF8Encoding]::new($false, $true)
            $value = $utf8.GetString($rawBytes)
            $normalized = $value.Replace("`r`n", "`n").Replace("`n", "`r`n")
            [byte[]]$candidate = [Text.Encoding]::UTF8.GetBytes($normalized)
            $candidateHash = [Convert]::ToHexString(
                [Security.Cryptography.SHA256]::HashData($candidate)
            ).ToLowerInvariant()
            if ($candidate.Length -eq [long]$item.bytes -and $candidateHash -eq $expected) {
                [IO.File]::WriteAllBytes($target, $candidate)
                $realSize = $candidate.Length
                $realHash = $candidateHash
                Write-Host "ORIGINAL CRLF RESTORED: $rel" -ForegroundColor Cyan
            }
        }
    }
    if ($realSize -ne [long]$item.bytes -or $realHash -ne $expected) {
        throw "DOWNLOAD CHECK FAIL: $rel (size=$realSize sha256=$realHash; expected size=$($item.bytes) sha256=$expected)"
    }
    Write-Host "SHA256 PASS $rel" -ForegroundColor Green
}
# Preserve any existing download untouched. A new sync destination must be empty.
if (Test-Path -LiteralPath $Destination) {
    throw "Destination exists; refusing to replace or delete working files: $Destination"
}
Move-Item -LiteralPath $stage -Destination $Destination
Write-Host "DOWNLOAD VERIFIED: $Destination" -ForegroundColor Green
$root = $Destination
$fm = Join-Path $root 'FileManager'
$fw = Join-Path $root 'firmware'
$original = Join-Path $root 'TP20_PiKoSoL_Run.ps1'
# Original runner expects firmware files next to script:
# tp20k_System_picorv32.fs at root; monitor/demo below firmware;
# host_console.py under tools. Copy only local verified original .fs into required location.
$originalFs = Join-Path $fw 'tp20k_System_picorv32.fs'
$workingFs = Join-Path $root 'tp20k_System_picorv32.fs'
if (!(Test-Path -LiteralPath $workingFs)) { Copy-Item -LiteralPath $originalFs -Destination $workingFs }
Write-Host 'RUN CHECKS: use --root to point GUI to this downloaded baseline.' -ForegroundColor Cyan
& python (Join-Path $fm 'PiKoSoL_FileManager.py') --root $root --check
if ($LASTEXITCODE -ne 0) { throw 'Local original firmware verification failed' }
& python (Join-Path $fm 'PiKoSoL_FileManager.py') --root $root --check-apps
if ($LASTEXITCODE -ne 0) { throw 'Downloaded apps offline ABI check failed' }
if ($BoardTest) {
    Write-Host 'SRAM-only FPGA programming + serial monitor upload will start.' -ForegroundColor Yellow
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $original -BoardTest -Port $Port
    if ($LASTEXITCODE -ne 0) { throw 'BoardTest failed' }
}
Write-Host 'READY: To launch GUI, run:' -ForegroundColor Green
Write-Host ('python "' + (Join-Path $fm 'PiKoSoL_FileManager.py') + '" --root "' + $root + '"')
