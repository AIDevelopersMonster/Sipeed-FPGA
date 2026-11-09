# Download Gowin HDMI IP from a pinned, public Sipeed repository revision.
# Does not modify FPGA, JTAG, Flash or any existing local project files.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$Commit = 'e23949a0a77381b94960cbc4e97a7c5e5ba8d222'
$Vendor = Join-Path $PSScriptRoot 'vendor'
New-Item -ItemType Directory -Force -Path $Vendor | Out-Null
$Files = @(
    @{ Name='TMDS_rPLL.v'; Source='hdmi/src/gowin_rpll/TMDS_rPLL.v'; Bytes=1823 },
    @{ Name='dvi_tx.v'; Source='hdmi/src/dvi_tx/dvi_tx.v'; Bytes=82427 }
)
$Manifest = @()
foreach ($item in $Files) {
    $dst = Join-Path $Vendor $item.Name
    $uri = "https://raw.githubusercontent.com/sipeed/TangNano-20K-example/$Commit/$($item.Source)"
    # Avoid silently overwriting an existing vendor IP file.
    if (Test-Path -LiteralPath $dst) {
        $got = (Get-Item -LiteralPath $dst).Length
        if ($got -ne $item.Bytes) {
            throw "Existing vendor source has unexpected length, refusing overwrite: $dst"
        }
        Write-Host "EXISTING: $dst"
    } else {
        $temp = "$dst.download"
        try {
            Invoke-WebRequest -Uri $uri -OutFile $temp -ErrorAction Stop
            $got = (Get-Item -LiteralPath $temp).Length
            if ($got -ne $item.Bytes) { throw "File size mismatch for $uri : $got" }
            Move-Item -LiteralPath $temp -Destination $dst
        } finally {
            if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp }
        }
    }
    $sha = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
    $Manifest += [ordered]@{
        name=$item.Name; url=$uri; size=(Get-Item -LiteralPath $dst).Length; sha256=$sha
    }
    Write-Host "READY: $($item.Name) SHA256 $sha"
}
$manifestFile = Join-Path $Vendor 'vendor_manifest.json'
$Manifest | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $manifestFile -Encoding utf8
Write-Host "VENDOR PREP COMPLETE; manifest $manifestFile"
Write-Host 'NOTE: DVI_TX_Top is vendor encrypted IP. Gowin version/IP compatibility is unverified.'
Write-Host 'NO JTAG / NO FLASH / NO FPGA WRITES'
