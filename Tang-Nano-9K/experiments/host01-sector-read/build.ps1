# HOST-01 isolated Gowin build, no FPGA programming.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$repo=Join-Path $here '..\..'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not (Test-Path -LiteralPath $gw -PathType Leaf)){throw "Missing Gowin CLI: $gw"}
$paths=@{
 'uart_rx_8n1.v'= (Join-Path $repo 'cores\uart-8n1\v1\rtl\uart_rx_8n1.v')
 'uart_tx_8n1.v'= (Join-Path $repo 'cores\uart-8n1\v1\rtl\uart_tx_8n1.v')
 'sync_fifo.v'= (Join-Path $repo 'cores\fifo-sync\v1\rtl\sync_fifo.v')
 'crc16_ccitt_byte.v'= (Join-Path $repo 'cores\crc16-ccitt\v1\rtl\crc16_ccitt_byte.v')
 'spi_byte.v'= (Join-Path $repo 'boards\tang-nano-9k\cores\sdhc-spi-readonly\v1\rtl\spi_byte.v')
 'sd_read_sector.v'= (Join-Path $repo 'boards\tang-nano-9k\cores\sdhc-spi-readonly\v1\rtl\sd_read_sector.v')
}
$job=Join-Path $here ('build\run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
$work=Join-Path $job 'work'
foreach($d in @($work,(Join-Path $work 'core'),(Join-Path $work 'rtl'),(Join-Path $work 'constraints'))){
 New-Item -ItemType Directory -Force -Path $d|Out-Null
}
foreach($name in $paths.Keys){
 if(-not (Test-Path -LiteralPath $paths[$name] -PathType Leaf)){throw "Missing core: $($paths[$name])"}
 Copy-Item -LiteralPath $paths[$name] -Destination (Join-Path $work ('core\'+$name))
}
foreach($name in @('host01_sector_engine.v','host01_sector_top.v')){
 Copy-Item -LiteralPath (Join-Path $here ('rtl\'+$name)) -Destination (Join-Path $work ('rtl\'+$name))
}
Copy-Item -LiteralPath (Join-Path $here 'constraints\host01_nano9k.cst') -Destination (Join-Path $work 'constraints')
Copy-Item -LiteralPath (Join-Path $here 'constraints\host01_nano9k.sdc') -Destination (Join-Path $work 'constraints')
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination $work
Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName | ForEach-Object {
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
}|Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Push-Location $work
try{& $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log');$rc=$LASTEXITCODE}finally{Pop-Location}
if($rc -ne 0){throw "HOST01_BUILD_FAIL: check $job\gowin_cli.log"}
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'host01_sector_nano9k.fs')
if($bits.Count -ne 1){throw "HOST01_BUILD_FAIL: found $($bits.Count) bitstreams"}
$fs=Join-Path $job 'host01_sector_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $fs
Write-Host "HOST01_BITSTREAM_CANDIDATE: $fs"
Write-Host "HOST01_SHA256: $((Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash)"
Write-Host "HOST01_INPUT_MANIFEST: $(Join-Path $job 'input_sha256.csv')"
Write-Host 'HOST01_BUILD_ONLY: run strict STA gate, never program without acceptance.'
