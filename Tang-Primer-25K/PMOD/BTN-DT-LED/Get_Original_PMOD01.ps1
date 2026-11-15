#Requires -Version 7.0
<#
Fetch unmodified Sipeed BTN/DT/LED example. No FPGA programming.
Files go into the ignored _vendor_original directory.
Each downloaded file is verified against its official Git blob SHA-1.
This newly prepared helper has not been operator-tested.
#>
[CmdletBinding()]
param([string]$Destination = (Join-Path $PSScriptRoot '_vendor_original'))
$ErrorActionPreference = 'Stop'
$commit = 'bc143318de1f397d4a98e19a94a9c23395fcb3d2'
$base = "https://raw.githubusercontent.com/sipeed/TangPrimer-25K-example/$commit/pmod_digitalTube-2bit"
$manifest = @(
    @{ Path = 'README.md';                    Blob = '9744f38830853ad04edfd34fc4f425eb0be19c1e' },
    @{ Path = 'pmod_digitalTube-2bit.gprj';    Blob = '8dcf69114c347e3e8e82233910de3bcd2d4eeb44' },
    @{ Path = 'src/top_demo.v';               Blob = '161a6180444e74b4cffc57b2469d34f585c0b722' },
    @{ Path = 'src/driver_Button.v';          Blob = '691cb95e0ad19f4dc9b664c3a0e844e76c7eacef' },
    @{ Path = 'src/driver_DigitalTube.v';     Blob = 'dc90a8a276772da1dadcf68c8627422bc51aa454' },
    @{ Path = 'src/driver_Led.v';             Blob = '3cd6a5453ed11f028abfe108716edc7127ec4efb' },
    @{ Path = 'src/pmod_digitalTube-2bit.cst';Blob = 'efa4baa1c10eb7e8f8b9e1b6ff9ccfafcbbe0516' },
    @{ Path = 'pmod_digitalTube-2bit.fs.7z';  Blob = '541d3092c981e2799bbcf8faa26e44421e0ae5d4' }
)
$git = (Get-Command git -ErrorAction Stop).Source
New-Item -ItemType Directory -Path $Destination -Force | Out-Null
foreach ($item in $manifest) {
    $target = Join-Path $Destination $item.Path
    New-Item -ItemType Directory -Force -Path (Split-Path $target -Parent) | Out-Null
    $tmp = "$target.download"
    if (Test-Path -LiteralPath $target) {
        $actual = (& $git hash-object -- $target | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw "git hash-object failed: $target" }
        if ($actual -eq $item.Blob) {
            Write-Host "VERIFIED (cached): $($item.Path)"
            continue
        }
        throw "Not overwriting modified local file: $target"
    }
    try {
        Invoke-WebRequest -Uri "$base/$($item.Path)" -OutFile $tmp
        $actual = (& $git hash-object -- $tmp | Out-String).Trim()
        if ($LASTEXITCODE -ne 0 -or $actual -ne $item.Blob) {
            throw "Git blob mismatch: $($item.Path) expected $($item.Blob) actual $actual"
        }
        Move-Item -LiteralPath $tmp -Destination $target
        Write-Host "VERIFIED: $($item.Path)"
    } finally {
        if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    }
}
$archive = Join-Path $Destination 'pmod_digitalTube-2bit.fs.7z'
Write-Host "OFFICIAL SOURCE VERIFIED, upstream commit: $commit"
Write-Host "Archive SHA256: $((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash)"
Write-Host "Gowin project: $(Join-Path $Destination 'pmod_digitalTube-2bit.gprj')"
Write-Host 'Download only: no new synthesis, no SRAM or Flash programming.'
