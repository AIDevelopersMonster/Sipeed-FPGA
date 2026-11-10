# TP20-02: download complete, known-good upstream nano-Z80 CP/Mish raw SD image.
# Windows PowerShell 5.1 and PowerShell 7.
# Host-file operation only: does not program FPGA or access physical microSD.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
if ($PSVersionTable.PSVersion.Major -le 5) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
}

$source = 'https://github.com/venomix666/nano-z80/releases/latest/download/nano-z80.img'
$expectedLength = 4186112
$expectedSha = '5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81'
$expectedHeader = '6E-61-6E-6F-00-00-00-01-0F-E0-F6'
$folder = Join-Path $PSScriptRoot 'downloads'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
$target = Join-Path $folder 'nano-z80.img'
$temp = Join-Path $folder 'nano-z80.img.partial'

Write-Host '=== TP20-02: download complete verified CP/Mish image ==='
Write-Host "SOURCE: $source"
Write-Host 'EXPECTED: 4186112 bytes (8176 x 512-byte sectors)'
Write-Host 'PHYSICAL SD WRITES: NONE; FPGA FLASH WRITES: NONE'
if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force }
try {
    # Download to temporary file; never trust an existing local cached .img.
    Invoke-WebRequest -Uri $source -OutFile $temp -MaximumRedirection 10 -ErrorAction Stop

    $len = (Get-Item -LiteralPath $temp).Length
    $hash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash.ToUpperInvariant()
    Write-Host "DOWNLOADED_BYTES=$len"
    Write-Host "DOWNLOADED_SHA256=$hash"
    if ($len -ne $expectedLength) {
        throw "IMAGE SIZE FAIL: expected $expectedLength bytes, got $len. 512-byte boot-sector-only file is NOT a full OS image. Existing target was not replaced."
    }
    if ($hash -cne $expectedSha) {
        throw "IMAGE SHA256 FAIL: release contents differ from the known image. STOP; existing target was not replaced."
    }
    $fs = [IO.File]::OpenRead($temp)
    try {
        $header = [byte[]]::new(11)
        $read = $fs.Read($header,0,$header.Length)
        if ($read -ne 11) { throw 'Failed to read 11-byte boot header' }
    }
    finally { $fs.Dispose() }
    $gotHeader = [BitConverter]::ToString($header)
    Write-Host "BOOT_HEADER_FIRST11=$gotHeader"
    if ($gotHeader -cne $expectedHeader) {
        throw 'IMAGE BOOT HEADER FAIL: existing target was not replaced.'
    }

    # Replace the local image ONLY after every verification succeeded.
    Move-Item -LiteralPath $temp -Destination $target -Force
    Write-Host 'FULL_IMAGE_DOWNLOAD_PASS'
    Write-Host "FILE=$target"
    Write-Host "BYTES=$len"
    Write-Host "SECTORS=$([int]($len / 512))"
    Write-Host "SHA256=$hash"
    Write-Host 'NEXT: write this complete image as RAW media, then VERIFY through your imaging application.'
}
finally {
    if (Test-Path -LiteralPath $temp) {
        Remove-Item -LiteralPath $temp -Force
    }
}
