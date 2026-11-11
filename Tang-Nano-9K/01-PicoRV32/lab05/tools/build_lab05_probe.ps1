# Isolated LAB-05 SD diagnostic Gowin synthesis/PnR, no programming.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$lab=Split-Path -Parent $PSScriptRoot
$cpu=Split-Path -Parent $lab
$gowin=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path -LiteralPath $gowin -PathType Leaf)) {
    throw "Missing Gowin CLI: $gowin"
}
$sourceFiles=@(
    'rtl\lab05_spi_byte.v',
    'rtl\lab05_sd_init_read0.v',
    'rtl\lab05_sd_probe_top.v',
    'constraints\lab05_sd_probe.cst',
    'constraints\lab05_sd_probe.sdc',
    'build_scripts\gowin_lab05_probe.tcl'
)
foreach($p in $sourceFiles) {
    if(-not (Test-Path -LiteralPath (Join-Path $lab $p) -PathType Leaf)) {
        throw "Missing LAB-05 source: $p"
    }
}
$uart=Join-Path $cpu 'rtl\uart_tx_8n1.v'
if(-not (Test-Path -LiteralPath $uart -PathType Leaf)) { throw "Missing UART source: $uart" }
$name='probe_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6)
$job=Join-Path $lab ('build\'+$name)
$work=Join-Path $job 'work'
foreach($d in @('lab05\rtl','lab05\constraints','rtl')) {
    New-Item -ItemType Directory -Force -Path (Join-Path $work $d) | Out-Null
}
foreach($p in $sourceFiles) {
    $dest = if ($p.StartsWith('build_scripts\')) { 'gowin_lab05_probe.tcl' } else { 'lab05\'+$p }
    Copy-Item -LiteralPath (Join-Path $lab $p) -Destination (Join-Path $work $dest)
}
Copy-Item -LiteralPath $uart -Destination (Join-Path $work 'rtl\uart_tx_8n1.v')
$files=@(Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName)
$files | ForEach-Object {
    [pscustomobject]@{
        Path=$_.FullName.Substring($work.Length+1)
        SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
} | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Push-Location $work
try {
    & $gowin 'gowin_lab05_probe.tcl' *> (Join-Path $job 'gowin_cli.log')
    $code=$LASTEXITCODE
} finally { Pop-Location }
if($code -ne 0) { throw "LAB05_GOWIN_ERROR code=$code; see $job\gowin_cli.log" }
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'lab05_sd_probe_nano9k.fs')
if($bits.Count -ne 1) { throw "Expected 1 bitstream, found $($bits.Count); inspect $job" }
$artifact=Join-Path $job 'lab05_sd_probe_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $artifact
Write-Host "LAB05_PROBE_BITSTREAM_CANDIDATE: $artifact"
Write-Host "LAB05_PROBE_SHA256: $((Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash)"
$reports=@(Get-ChildItem -LiteralPath $work -Recurse -File |
    Where-Object { $_.Name -in @('lab05_sd_probe_nano9k.rpt.txt','lab05_sd_probe_nano9k_tr_content.html','lab05_sd_probe_nano9k.log') })
foreach($r in $reports) { Write-Host "LAB05_REPORT: $($r.FullName)" }
Write-Host 'LAB05_PROBE_BUILD_CANDIDATE_ONLY: inspect PnR utilization and complete setup/hold before any SRAM programming.'
