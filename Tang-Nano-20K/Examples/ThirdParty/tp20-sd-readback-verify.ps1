# TP20-02: verify microSD physical sectors 0..8175 against the confirmed nano-z80.img.
# READ ONLY: opens \\.\PhysicalDriveN with FileAccess.Read. Does not write, format,
# lock, dismount, partition or modify the SD card, FPGA or firmware.
# Run elevated PowerShell if Windows refuses raw physical disk read access.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateRange(0, 999)]
    [int]$DiskNumber,
    [string]$Image = (Join-Path $PSScriptRoot 'downloads\nano-z80.img')
)
$ErrorActionPreference = 'Stop'

$expectedSize = 4186112
$expectedSha256 = '5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81'
$devicePath = '\\.\PhysicalDrive' + $DiskNumber

if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) {
    throw "Reference image missing: $Image"
}
$reference = Get-Item -LiteralPath $Image
$imageSha256 = (Get-FileHash -LiteralPath $reference.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
Write-Host "REFERENCE_FILE=$($reference.FullName)"
Write-Host "REFERENCE_BYTES=$($reference.Length)"
Write-Host "REFERENCE_SHA256=$imageSha256"
if ($reference.Length -ne $expectedSize -or $imageSha256 -cne $expectedSha256) {
    throw 'Reference image does NOT match confirmed host image. STOP.'
}
if (($expectedSize % 512) -ne 0) { throw 'Image is not sector aligned' }

$disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
Write-Host "TARGET_PHYSICAL_DISK=$devicePath"
Write-Host ("DISK: NUMBER={0} NAME={1} BUS={2} BYTES={3} BOOT={4} SYSTEM={5} PARTITION_STYLE={6}" -f $disk.Number,$disk.FriendlyName,$disk.BusType,$disk.Size,$disk.IsBoot,$disk.IsSystem,$disk.PartitionStyle)
if ($disk.IsBoot -or $disk.IsSystem) {
    throw 'Refusing system or boot disk, even for READ ONLY. STOP.'
}
if (([string]$disk.BusType) -notin @('USB','SD')) {
    throw 'Refusing non-USB/non-SD disk. Verify target and STOP.'
}
if ($disk.Size -lt 12GB -or $disk.Size -gt 20GB) {
    throw 'Unexpected disk capacity (operator candidate was 16GB). Verify target and STOP.'
}
if ($disk.Size -lt $expectedSize) {
    throw 'Physical disk is smaller than reference image. STOP.'
}

$referenceBytes = [IO.File]::ReadAllBytes($reference.FullName)
$readback = [byte[]]::new($expectedSize)
$stream = $null

try {
    $stream = [IO.FileStream]::new(
        $devicePath,
        [IO.FileMode]::Open,
        [IO.FileAccess]::Read,
        [IO.FileShare]::ReadWrite
    )
    # Reading precisely the image length from physical byte offset zero.
    $offset = 0
    while ($offset -lt $readback.Length) {
        $n = $stream.Read($readback, $offset, $readback.Length - $offset)
        if ($n -le 0) { throw "Unexpected EOF at physical byte offset $offset" }
        $offset += $n
    }
}
catch [System.UnauthorizedAccessException] {
    throw "Windows denied READ-ONLY access to $devicePath. Run PowerShell as Administrator; do NOT format or dismount."
}
finally {
    if ($null -ne $stream) { $stream.Dispose() }
}

$hasher = [Security.Cryptography.SHA256]::Create()
try {
    $sdSha256 = [BitConverter]::ToString($hasher.ComputeHash($readback)).Replace('-','')
}
finally {
    $hasher.Dispose()
}
Write-Host "READBACK_BYTES=$expectedSize"
Write-Host "READBACK_SECTORS=$($expectedSize / 512)"
Write-Host "READBACK_SHA256=$sdSha256"
Write-Host "READBACK_SECTOR0_FIRST16=$([BitConverter]::ToString($readback,0,16))"
Write-Host "REFERENCE_SECTOR0_FIRST16=$([BitConverter]::ToString($referenceBytes,0,16))"

$match = $sdSha256 -ceq $imageSha256
$mismatch = -1
if (-not $match) {
    for ($i = 0; $i -lt $expectedSize; $i++) {
        if ($readback[$i] -ne $referenceBytes[$i]) {
            $mismatch = $i
            break
        }
    }
    if ($mismatch -ge 0) {
        Write-Host ('FIRST_MISMATCH: OFFSET={0} SECTOR={1} OFFSET_IN_SECTOR={2} EXPECTED=0x{3:X2} ACTUAL=0x{4:X2}' -f $mismatch,[math]::Floor($mismatch/512),($mismatch%512),$referenceBytes[$mismatch],$readback[$mismatch])
    }
    Write-Host 'TP20-02 RAW_SD_READBACK_FAIL'
    Write-Host 'Do not attempt CP/M boot. Investigate physical image write/reader first.'
    throw 'Physical SD readback SHA256 differs from confirmed nano-z80.img.'
}

Write-Host 'TP20-02 RAW_SD_READBACK_PASS'
Write-Host 'The first 4,186,112 bytes of this SD card match the image by SHA256.'
Write-Host 'This verifies host-side SD image writing. FPGA SD sector reads and RAM writes remain separate tests.'
Write-Host 'NO_PHYSICAL_DISK_WRITES=TRUE'
