# TP20-02: read-only expected CP/Mish RAM bytes from the operator's nano-z80.img.
# Does not touch physical SD, FPGA, UART, system partitions, or any file contents.
# Cross-check ROM Monitor dumps after L against the image which was downloaded.
[CmdletBinding()]
param(
 [string]$Image = (Join-Path $PSScriptRoot 'downloads\nano-z80.img')
)
$ErrorActionPreference = 'Stop'
$expectedLength = 4186112
$expectedSha = '5B92105D34D0BCE698EA419F2342A4C213EAFAB064C06757A332FC050CF6FA81'
if (-not (Test-Path -LiteralPath $Image -PathType Leaf)) { throw "Image missing: $Image" }
$file = Get-Item -LiteralPath $Image
$sha = (Get-FileHash -LiteralPath $Image -Algorithm SHA256).Hash
if ($file.Length -ne $expectedLength -or $sha -ne $expectedSha) {
 throw "Unexpected image size or SHA256: $($file.Length) bytes; $sha. Stop."
}
$stream = [IO.File]::OpenRead($file.FullName)
function Dump-ImageAsRam([int]$Address,[int]$Count) {
    # Boot sector declares start SD LBA=1, 15*512-byte sectors at RAM E000.
    if ($Address -lt 0xE000 -or ($Address+$Count) -gt 0xFE00) {
      throw "Requested address not contained in boot image: $Address"
    }
    $startOffset = 512 + ($Address - 0xE000)
    $stream.Position = $startOffset
    $buffer = [byte[]]::new($Count)
    $read = $stream.Read($buffer,0,$Count)
    if ($read -ne $Count) { throw "Short image read" }
    Write-Host ('RAM_{0:X4} IMAGE_OFFSET_0x{1:X5} ({2} bytes)' -f $Address,$startOffset,$Count)
    for($n=0;$n -lt $Count;$n+=16) {
       $end=[Math]::Min($Count-1,$n+15)
       $line=($buffer[$n..$end] | ForEach-Object {$_.ToString('X2')}) -join ' '
       Write-Host ('{0:X4}: {1}' -f ($Address+$n),$line)
    }
}
try {
    $h=[byte[]]::new(16)
    $stream.Position=0
    if($stream.Read($h,0,16) -ne 16){throw 'Cannot read boot header'}
    $hdr=([BitConverter]::ToString($h))
    Write-Host '== TP20-02: CP/Mish image-to-RAM map (READ ONLY) =='
    Write-Host "FILE=$($file.FullName)"
    Write-Host "BYTES=$($file.Length)"
    Write-Host "SHA256=$sha"
    Write-Host "BOOT_HEADER=$hdr"
    if(([Text.Encoding]::ASCII.GetString($h,0,4)) -cne 'nano' -or $h[4] -ne 0 -or $h[5] -ne 0 -or $h[6] -ne 0 -or $h[7] -ne 1 -or $h[8] -ne 15 -or $h[9] -ne 224 -or $h[10] -ne 246){
       throw 'Expected boot parameters not found; stop'
    }
    foreach($range in @(
        @(0xE000,32),
        @(0xF600,64),
        @(0xF630,16),
        @(0xF800,64),
        @(0xF830,16)
    )){
        Dump-ImageAsRam -Address $range[0] -Count $range[1]
    }
    Write-Host 'F633 and F833 are visible within F630 and F830 rows (4th byte, respectively).'
    Write-Host 'Compare with Z80 ROM monitor: MFFFF,0001 ; ME000,0020 ; MF600,0040 ; MF800,0040'
    Write-Host 'DO NOT execute WF633,83 or JF600 until the expected BIOS address is validated.'
    Write-Host 'PASS HOST FILE MAP ONLY: no SD/FPGA modification.'
} finally {
    $stream.Dispose()
}
