# HOST-00.1: reproducible Gowin build. Build only; never programs FPGA or SD.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$repo=Join-Path $here '..\..'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not (Test-Path -LiteralPath $gw -PathType Leaf)){
    throw "HOST00_BUILD_FAIL: Gowin CLI not found: $gw"
}
$uart=Join-Path $repo 'cores\uart-8n1\v1\rtl'
$fifo=Join-Path $repo 'cores\fifo-sync\v1\rtl'
$required=@(
    (Join-Path $uart 'uart_rx_8n1.v'),
    (Join-Path $uart 'uart_tx_8n1.v'),
    (Join-Path $fifo 'sync_fifo.v'),
    (Join-Path $here 'rtl\host00_hello.v'),
    (Join-Path $here 'rtl\host00_uart_hello_top.v'),
    (Join-Path $here 'constraints\host00_nano9k.cst'),
    (Join-Path $here 'constraints\host00_nano9k.sdc'),
    (Join-Path $here 'build.tcl')
)
foreach($f in $required){
    if(-not (Test-Path -LiteralPath $f -PathType Leaf)){
        throw "HOST00_BUILD_FAIL: missing source $f"
    }
}
$id=(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6)
$job=Join-Path $here ('build\run_'+$id)
$work=Join-Path $job 'work'
foreach($d in @($job,$work,(Join-Path $work 'core'),(Join-Path $work 'rtl'),
                (Join-Path $work 'constraints'))){
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}
# One source per component; snapshots are only in this untracked build directory.
foreach($n in @('uart_rx_8n1.v','uart_tx_8n1.v')){
    Copy-Item -LiteralPath (Join-Path $uart $n) -Destination (Join-Path $work ('core\'+$n))
}
Copy-Item -LiteralPath (Join-Path $fifo 'sync_fifo.v') -Destination (Join-Path $work 'core\sync_fifo.v')
foreach($n in @('host00_hello.v','host00_uart_hello_top.v')){
    Copy-Item -LiteralPath (Join-Path $here ('rtl\'+$n)) -Destination (Join-Path $work ('rtl\'+$n))
}
foreach($n in @('host00_nano9k.cst','host00_nano9k.sdc')){
    Copy-Item -LiteralPath (Join-Path $here ('constraints\'+$n)) -Destination (Join-Path $work ('constraints\'+$n))
}
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination (Join-Path $work 'build.tcl')
$manifest=@(Get-ChildItem -LiteralPath $work -File -Recurse | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{
        Path=$_.FullName.Substring($work.Length+1)
        SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
})
$manifest | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Push-Location $work
try {
    & $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log')
    $rc=$LASTEXITCODE
} finally {
    Pop-Location
}
if($rc -ne 0){
    throw "HOST00_BUILD_FAIL: Gowin exit=$rc; see $job\gowin_cli.log"
}
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'host00_uart_hello_nano9k.fs')
if($bits.Count -ne 1){
    throw "HOST00_BUILD_FAIL: expected exactly one .fs, found $($bits.Count)"
}
$fs=Join-Path $job 'host00_uart_hello_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $fs
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "HOST00_BITSTREAM_CANDIDATE: $fs"
Write-Host "HOST00_SHA256: $sha"
Write-Host "HOST00_INPUT_MANIFEST: $(Join-Path $job 'input_sha256.csv')"
Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object {
    $_.Name -match '\.rpt\.txt$|_tr_content\.html$|\.log$'
} | ForEach-Object {Write-Host "HOST00_REPORT: $($_.FullName)"}
Write-Host 'HOST00_BUILD_ONLY: verify SHA, setup/hold, TNS and pins before SRAM-only programming.'
