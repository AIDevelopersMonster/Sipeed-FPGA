# TP20-01: standalone downloader for nano-Z80 without a Git checkout.
# Runs on Windows PowerShell 5.1 / PowerShell 7.
# Default: download documentation, FPGA bitstream and upstream source archive.
# Optional -LoadSRAM: load the bitstream into VOLATILE FPGA SRAM only.
# NEVER uses openFPGALoader -f and NEVER changes external PLL.
[CmdletBinding()]
param(
    [switch]$LoadSRAM,
    [switch]$Refresh,
    [switch]$SkipSource
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
$root = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($root)) { throw "Cannot locate the script folder" }
$docsBase = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Nano-20K/Examples/ThirdParty'
$releaseUrl = 'https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.fs'
$upstreamCommit = '0e2692ad10da8cbc0351758fea0fffa2dcf30110'
$sourceUrl = "https://codeload.github.com/venomix666/nano-z80/zip/$upstreamCommit"
$downloads = Join-Path $root 'downloads'
$sources = Join-Path $root 'sources'
New-Item -ItemType Directory -Force -Path $downloads, $sources | Out-Null

function Fetch-File {
    param(
        [Parameter(Mandatory=$true)][string]$Uri,
        [Parameter(Mandatory=$true)][string]$Target,
        [int64]$MinBytes = 64
    )
    if (Test-Path -LiteralPath $Target) {
        $existing = Get-Item -LiteralPath $Target
        if ((-not $Refresh) -and $existing.Length -ge $MinBytes) {
            Write-Host "[CACHED] $Target ($($existing.Length) bytes)"
            return
        }
    }
    $temp = "$Target.partial"
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    Write-Host "[GET] $Uri"
    try {
        Invoke-WebRequest -Uri $Uri -OutFile $temp -MaximumRedirection 10 -ErrorAction Stop
        $item = Get-Item -LiteralPath $temp -ErrorAction Stop
        if ($item.Length -lt $MinBytes) {
            throw "Invalid/short download: $($item.Length) bytes; expected >= $MinBytes"
        }
        Move-Item -LiteralPath $temp -Destination $Target -Force
        Write-Host "[OK] $Target ($($item.Length) bytes)"
    } finally {
        if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
    }
}

Write-Host "== TP20-01: nano-Z80 standalone preparation =="
Write-Host "ROOT: $root"
Write-Host "No git pull, no git branch switching, no flash writes."

$docs = @('README.md', 'NANO_Z80_QUICK_DEMO_RU.md', 'EXTENDED_ANALYSIS_RU.md', 'get-nano-z80.ps1')
foreach ($doc in $docs) {
    Fetch-File -Uri "$docsBase/$doc" -Target (Join-Path $root $doc) -MinBytes 100
}

$fs = Join-Path $downloads 'nano-z80.fs'
Fetch-File -Uri $releaseUrl -Target $fs -MinBytes 1024
$fsItem = Get-Item -LiteralPath $fs
$fsSha = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "BITSTREAM: $($fsItem.Length) bytes; SHA256=$fsSha"

$archive = Join-Path $sources "nano-z80-$upstreamCommit.zip"
$sourceStatus = 'SKIPPED'
if (-not $SkipSource) {
    try {
        Fetch-File -Uri $sourceUrl -Target $archive -MinBytes 1024
        $sourceStatus = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
        $marker = Join-Path $sources "nano-z80-$upstreamCommit"
        if ((-not (Test-Path -LiteralPath $marker)) -or $Refresh) {
            Write-Host "Extracting source archive to $sources"
            Expand-Archive -LiteralPath $archive -DestinationPath $sources -Force
        }
    } catch {
        $sourceStatus = "FAILED: $($_.Exception.Message)"
        Write-Warning "Source archive is optional for the HDMI demo: $sourceStatus"
    }
}

$manifest = Join-Path $downloads 'TP20-01_DOWNLOAD_MANIFEST.txt'
@(
    "PROJECT=TP20-01 nano-Z80"
    "DATE_UTC=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    "BITSTREAM_SOURCE=$releaseUrl"
    "BITSTREAM_PATH=$fs"
    "BITSTREAM_SIZE=$($fsItem.Length)"
    "BITSTREAM_SHA256=$fsSha"
    "SOURCE_COMMIT=$upstreamCommit"
    "SOURCE_ARCHIVE=$archive"
    "SOURCE_SHA256_OR_STATUS=$sourceStatus"
    "FLASH_WRITES=NO"
    "BOARD_STATUS=NOT_TESTED"
) | Set-Content -LiteralPath $manifest -Encoding UTF8
Write-Host "MANIFEST: $manifest"
Write-Host "INSTRUCTION: $(Join-Path $root 'NANO_Z80_QUICK_DEMO_RU.md')"

if (-not $LoadSRAM) {
    Write-Host ""
    Write-Host "DOWNLOAD COMPLETE; NO PROGRAMMING PERFORMED."
    Write-Host "After checking PLL O0=25.175 MHz and O1=12 MHz:"
    Write-Host "  & '$PSCommandPath' -LoadSRAM -SkipSource"
    exit 0
}

$loader = Get-Command openFPGALoader -ErrorAction SilentlyContinue
if (-not $loader) { $loader = Get-Command openFPGALoader.exe -ErrorAction SilentlyContinue }
if (-not $loader) {
    throw "openFPGALoader is not on PATH. Files downloaded; no programming performed. Find the programmer used for EX20-01."
}
Write-Warning "External PLL outputs O0=25.175 MHz and O1=12 MHz must be configured separately and verified."
Write-Warning "This operation REPLACES the active factory LiteX SRAM image until power-cycle; FPGA FLASH is NOT written."
$answer = Read-Host 'Type exactly SRAM to load the FPGA temporarily'
if ($answer -cne 'SRAM') { throw 'Cancelled; no programming performed' }
& $loader.Source '-b' 'tangnano20k' $fs
if ($LASTEXITCODE -ne 0) { throw "openFPGALoader exited with code $LASTEXITCODE" }
Write-Host "Programmer exited successfully. Confirm HDMI and COM 115200 8N1 on physical board."
Write-Host "BOARD STATUS: NOT TESTED until operator verifies ROM monitor."
