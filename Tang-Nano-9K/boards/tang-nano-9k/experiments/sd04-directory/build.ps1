# SD-04: reproducible read-only Gowin build, NO programming.
# Requires PowerShell 7, Python, Icarus Verilog and installed Gowin CLI.
# Reuses exact source files from the frozen SD-03 experiment; stages copies
# only into a unique ignored build/ directory, records their SHA-256 hashes.
[CmdletBinding()]
param(
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$sd03 = Join-Path (Split-Path -Parent $here) 'sd-mbr-fat32'
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path -LiteralPath $gw -PathType Leaf)) {
    throw "Gowin CLI is missing: $gw"
}
if (-not (Test-Path -LiteralPath (Join-Path $here 'test.ps1') -PathType Leaf)) {
    throw 'Missing SD-04 local regression entrypoint'
}

Write-Host 'SD04_GATE: running existing Python and Icarus regressions...'
& (Join-Path $here 'test.ps1')
if (-not $?) { throw 'SD-04 regression failed; refusing Gowin build' }

$run = ('run_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '_' +
       [guid]::NewGuid().ToString('N').Substring(0, 6))
$job = Join-Path $here ('build\' + $run)
$work = Join-Path $job 'work'
New-Item -ItemType Directory -Force -Path (Join-Path $work 'rtl'), (Join-Path $work 'constraints') | Out-Null

$rtlFiles = @(
    'spi_byte.v',
    'sd_read_sector.v',
    'uart_tx_8n1.v',
    'sd03_mbr_parser.v',
    'sd03_fat32_bpb.v',
    'sd03_volume_scanner.v'
)
foreach ($filename in $rtlFiles) {
    $src = Join-Path $sd03 ('rtl\' + $filename)
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        throw "SD-03 frozen source not found: $src"
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $work ('rtl\' + $filename))
}
foreach ($filename in @('sd03_nano9k.cst','sd03_nano9k.sdc')) {
    $src = Join-Path $sd03 ('constraints\' + $filename)
    if (-not (Test-Path -LiteralPath $src -PathType Leaf)) {
        throw "SD-03 frozen constraint not found: $src"
    }
    Copy-Item -LiteralPath $src -Destination (Join-Path $work ('constraints\' + $filename))
}
Copy-Item -LiteralPath (Join-Path $here 'rtl\sd04_root_dump_top.v') -Destination (Join-Path $work 'rtl\sd04_root_dump_top.v')
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination (Join-Path $work 'build.tcl')

Get-ChildItem -LiteralPath $work -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
        [pscustomobject]@{
            Path   = $_.FullName.Substring($work.Length + 1)
            SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    } | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8

$commit = & git -C $here rev-parse HEAD 2>$null
if ($LASTEXITCODE -eq 0) {
    Set-Content -LiteralPath (Join-Path $job 'git_head.txt') -Value $commit -Encoding ascii
}

$log = Join-Path $job 'gowin_cli.log'
Write-Host "SD04_BUILD_RUN: $job"
Push-Location $work
try {
    & $gw 'build.tcl' *> $log
    $rc = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($rc -ne 0) {
    throw "Gowin failed with exit=$rc; inspect $log"
}

$bitstreams = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'sd04_root_dump_nano9k.fs')
if ($bitstreams.Count -ne 1) {
    throw "Expected exactly one SD-04 bitstream; found $($bitstreams.Count). Inspect $log"
}
$fs = Join-Path $job 'sd04_root_dump_nano9k.fs'
Copy-Item -LiteralPath $bitstreams[0].FullName -Destination $fs
$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "SD04_BITSTREAM_CANDIDATE: $fs"
Write-Host "SD04_SHA256: $hash"
Write-Host "SD04_INPUT_MANIFEST: $(Join-Path $job 'input_sha256.csv')"
Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object {
    $_.Name -match '\.rpt\.txt$|_tr_content\.html$|\.log$'
} | ForEach-Object {
    Write-Host "SD04_REPORT: $($_.FullName)"
}
Write-Host 'SD04_BUILD_ONLY: Do NOT program FPGA until setup/hold STA, resource and external SD IO timing are reviewed.'
