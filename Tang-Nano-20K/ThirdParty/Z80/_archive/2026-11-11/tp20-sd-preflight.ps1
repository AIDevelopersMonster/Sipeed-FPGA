# TP20-02 CP/Mish SD card preflight, Windows PowerShell 5.1+/PowerShell 7.
# DEFAULT READ-ONLY: validates downloaded image and inventories Windows disks.
# Explicit -InstallImager installs the official Raspberry Pi Imager via winget.
# This script NEVER writes, formats, dismounts, or alters any physical storage,
# and NEVER programs FPGA flash or changes clock frequencies.
[CmdletBinding()]
param([switch]$InstallImager)
$ErrorActionPreference = 'Stop'
$img = Join-Path $PSScriptRoot 'downloads\nano-z80.img'
$expectedSize = 4186112
$expectedSha = '5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81'
$evidenceDir = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Path $evidenceDir -Force | Out-Null
$log = Join-Path $evidenceDir ("TP20_SD_PREFLIGHT_" + (Get-Date -Format 'yyyyMMdd_HHmmss') + ".txt")
$messages = New-Object 'System.Collections.Generic.List[string]'
function Note([string]$message) {
    Write-Host $message
    [void]$messages.Add($message)
}
try {
    Note 'TP20-02 SD PREFLIGHT: NO SD WRITES / NO FPGA WRITES'
    if (-not (Test-Path -LiteralPath $img -PathType Leaf)) {
        throw "Missing image: $img. Run prepare-tp20-sd.ps1"
    }
    $file = Get-Item -LiteralPath $img
    $sha = (Get-FileHash -LiteralPath $img -Algorithm SHA256).Hash
    Note "IMAGE=$img"
    Note "IMAGE_SIZE=$($file.Length)"
    Note "IMAGE_SHA256=$sha"
    if ($file.Length -ne $expectedSize -or $sha -ne $expectedSha) {
        throw "Image fingerprint differs from operator-verified image; STOP. Image expected bytes=$expectedSize and SHA256=$expectedSha."
    }
    $fh = [System.IO.File]::OpenRead($img)
    try {
        $first = [byte[]]::new(16)
        $read = $fh.Read($first,0,$first.Length)
        if ($read -ne $first.Length) { throw "Cannot read 16-byte boot header" }
    } finally {
        $fh.Dispose()
    }
    $magic = [System.Text.Encoding]::ASCII.GetString($first,0,4)
    Note "MAGIC=$magic"
    Note "HEADER_FIRST16=$([BitConverter]::ToString($first))"
    if ($magic -cne 'nano' -or $first[4] -ne 0 -or $first[5] -ne 0 -or $first[6] -ne 0 -or $first[7] -ne 1 -or $first[8] -ne 15 -or $first[9] -ne 224 -or $first[10] -ne 246) {
        throw 'Boot header differs from verified CP/Mish image; STOP.'
    }
    Note 'IMAGE PREPARED PASS: hash + nano signature + boot page verified.'
    Note '--- Windows disk inventory (READ ONLY) ---'
    $disks = @(Get-Disk -ErrorAction Stop | Sort-Object Number)
    foreach ($d in $disks) {
        $gb = [math]::Round([double]$d.Size / 1GB,2)
        Note ("DISK #{0} | NAME={1} | BUS={2} | GB={3} | BOOT={4} | SYSTEM={5} | PARTITION_STYLE={6} | OFFLINE={7}" -f $d.Number,$d.FriendlyName,$d.BusType,$gb,$d.IsBoot,$d.IsSystem,$d.PartitionStyle,$d.IsOffline)
        try {
            foreach ($p in @(Get-Partition -DiskNumber $d.Number -ErrorAction Stop)) {
                Note ("   PARTITION #{0} | LETTER={1} | BYTES={2}" -f $p.PartitionNumber,$p.DriveLetter,$p.Size)
            }
        } catch {
            Note "   PARTITIONS UNAVAILABLE: $($_.Exception.Message)"
        }
    }
    Note 'Choose target card in the imaging GUI by disk MODEL and CAPACITY; not by an assumed drive letter.'
    Note 'Never select a disk marked BOOT=True or SYSTEM=True.'
    if ($InstallImager) {
        $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
        if (-not $winget) { throw 'winget is missing. Install Raspberry Pi Imager from https://www.raspberrypi.com/software/' }
        Note 'EXPLICIT INSTALLIMAGER MODE: installing Raspberry Pi Imager with winget. Physical disks are NOT written.'
        & $winget.Source install --exact --id RaspberryPiFoundation.RaspberryPiImager --source winget --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -ne 0) { throw "winget install failed, exit code $LASTEXITCODE" }
        Note 'Raspberry Pi Imager installer completed.'
    } else {
        Note 'If needed: .\tp20-sd-preflight.ps1 -InstallImager (installs only GUI app; no SD write)'
    }
    Note 'IN GUI: Raspberry Pi Imager > choose a custom image > downloads\nano-z80.img > verify microSD model+capacity > WRITE > VERIFY.'
    Note 'Windows may ask to format the raw CP/M media after writing: CANCEL/IGNORE, do not format.'
    Note 'Then safely eject the card, insert into Tang Nano 20K, use S2 to reset with MS5351 O0/O1 on, and follow TP20-02_SD_CPM_FUZIX_RU.md.'
    Note 'PREFLIGHT COMPLETED; PHYSICAL_DISK_WRITES=NO; BOARD_SD_TEST=NOT YET TESTED'
} catch {
    Note "PREFLIGHT FAILED: $($_.Exception.Message)"
    throw
} finally {
    $messages | Set-Content -LiteralPath $log -Encoding UTF8
    Write-Host "EVIDENCE: $log"
}
