# EX20-01 HDMI: download and fingerprint only. NO hardware programming.
[CmdletBinding()]
param(
    [string]$OutDir = (Join-Path $PSScriptRoot "artifacts")
)
$ErrorActionPreference = "Stop"
$uri = "https://raw.githubusercontent.com/sipeed/TangNano-20K-example/main/hdmi/hdmi.fs"
$expectedBytes = 4619320
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$dst = Join-Path $OutDir "sipeed_hdmi_20k.fs"
$tmp = "$dst.part"
try {
    Invoke-WebRequest -Uri $uri -OutFile $tmp -MaximumRedirection 5
    $actual = (Get-Item -LiteralPath $tmp).Length
    if ($actual -ne $expectedBytes) {
        throw "Size mismatch: expected $expectedBytes, got $actual bytes. File not accepted."
    }
    Move-Item -LiteralPath $tmp -Destination $dst -Force
    $hash = (Get-FileHash -LiteralPath $dst -Algorithm SHA256).Hash.ToLowerInvariant()
    $summary = [ordered]@{
        test = "EX20-01 HDMI preparation"
        status = "SOURCE_DOWNLOADED_NOT_BOARD_TESTED"
        source = $uri
        bytes = $actual
        sha256 = $hash
        file = $dst
        flash_written = $false
        fpga_programmed = $false
        timestamp_local = (Get-Date).ToString("o")
    }
    $json = Join-Path $OutDir "hdmi_source_manifest.json"
    $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $json -Encoding utf8
    Write-Host "PREP PASS: $actual bytes; SHA256 $hash"
    Write-Host "FILE: $dst"
    Write-Host "MANIFEST: $json"
    Write-Host "NO JTAG / NO COM / NO FPGA WRITES. Use Gowin Programmer SRAM Mode manually."
} finally {
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
}
