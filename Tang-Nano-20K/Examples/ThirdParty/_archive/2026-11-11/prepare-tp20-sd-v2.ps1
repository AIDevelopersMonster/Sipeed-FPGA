# TP20-02 SD DOWNLOADER VERSION 2.1 (cache-busting new filename; 2026-11-11)
# TP20-02: download upstream raw SD images for nano-Z80 CP/Mish and optionally FUZIX.
# DEFAULT IS READ-ONLY TO YOUR SD CARDS: NEVER opens physical drives,
# NEVER formats SD, NEVER writes images to a device, FPGA, or Flash.
# Windows PowerShell 5.1 / PowerShell 7.
[CmdletBinding()]
param([switch]$WithFuzix,[switch]$Refresh)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}
$root = $PSScriptRoot
$dir = Join-Path $root 'downloads'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
$manifest = Join-Path $dir 'TP20-02_SD_DOWNLOAD_MANIFEST.txt'
$urlCpm = 'https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.img'
$urlFuzix = 'https://github.com/venomix666/nano-z80/releases/latest/download/FUZIX-disk.img'

function Fetch-Image([string]$url, [string]$path) {
    if ((Test-Path -LiteralPath $path -PathType Leaf) -and (-not $Refresh)) {
        Write-Host "[CACHED] $path"
        return
    }
    $part = "$path.partial"
    if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
    Write-Host "[DOWNLOAD] $url"
    try {
        Invoke-WebRequest -Uri $url -OutFile $part -MaximumRedirection 10 -ErrorAction Stop
        $length = (Get-Item -LiteralPath $part).Length
        if ($length -lt 8192 -or ($length % 512) -ne 0) {
            throw "Invalid raw image size $length (minimum 8192 and multiple of 512). No SD card was modified."
        }
        Move-Item -LiteralPath $part -Destination $path -Force
        Write-Host "[OK] $path ($length bytes)"
    } finally {
        if (Test-Path -LiteralPath $part) { Remove-Item -LiteralPath $part -Force }
    }
}
function Inspect-Image([string]$path, [string]$name, [bool]$requireNano) {
    $file = Get-Item -LiteralPath $path
    if ($file.Length -lt 8192 -or ($file.Length % 512) -ne 0) {
        throw "${name}: length $($file.Length) is not a valid raw block image size"
    }
    $s = [System.IO.File]::OpenRead($path)
    try {
        $bytes = [byte[]]::new(16)
        $n = $s.Read($bytes,0,$bytes.Length)
        if ($n -ne $bytes.Length) { throw "Unable to read first 16 bytes" }
    } finally {
        $s.Dispose()
    }
    $magic = [System.Text.Encoding]::ASCII.GetString($bytes,0,4)
    $head = [System.BitConverter]::ToString($bytes)
    if ($requireNano -and $magic -cne 'nano') {
        throw "${name}: NO nano ROM boot signature at sector 0. Found HEX=$head. Do not write this image to SD."
    }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $source = if ($requireNano) { $urlCpm } else { $urlFuzix }
    $data = @(
        "NAME=$name",
        "SOURCE=$source",
        "PATH=$path",
        "BYTES=$($file.Length)",
        "SHA256=$hash",
        "SECTOR0_FIRST16=$head",
        "NANO_BOOT_SIGNATURE=$(if ($magic -ceq 'nano') {'YES'} else {'NO / NOT_REQUIRED'})"
    )
    foreach ($line in $data) { Write-Host $line }
    if ($requireNano) {
        Write-Host "CPM BOOT SECTOR: source-LBA-bytes $([System.BitConverter]::ToString($bytes,4,4)); page count $($bytes[8]); RAM page 0x$($bytes[9].ToString('X2')); jump page 0x$($bytes[10].ToString('X2'))"
    }
    return ($data -join [Environment]::NewLine)
}
Write-Host "=== TP20-02 SD Downloader v2.1 ==="
Write-Host "SCRIPT_VERSION=2.1; VARIABLE_COLON_FIX=PASS"
Write-Host "No physical disk writes. No FPGA/JTAG/PLL operations."
$cpm = Join-Path $dir 'nano-z80.img'
Fetch-Image $urlCpm $cpm
$entries = @(
    "PROJECT=TP20-02 nano-Z80 SD images",
    "DATE_UTC=$([DateTime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ'))",
    "PHYSICAL_DISK_WRITES=NONE",
    "BOARD_STATUS=SD NOT TESTED",
    (Inspect-Image $cpm 'CPMISH' $true)
)
if ($WithFuzix) {
    $fuzix = Join-Path $dir 'FUZIX-disk.img'
    Fetch-Image $urlFuzix $fuzix
    $entries += Inspect-Image $fuzix 'FUZIX' $false
    Write-Host "FUZIX IMAGE RESERVED OFFSET: 0x100000 * 512 = 536870912 bytes (512 MiB)."
}
$entries | Set-Content -LiteralPath $manifest -Encoding UTF8
Write-Host "MANIFEST: $manifest"
Write-Host "DOWNLOAD PASS: images are files on your Windows PC only; your SD card has NOT been changed."
Write-Host "Before writing a raw disk image, use a dedicated blank/spare card and back up all existing files."
Write-Host "See TP20-02_SD_CPM_FUZIX_RU.md for the operator-driven card imaging and UART-console procedure."
