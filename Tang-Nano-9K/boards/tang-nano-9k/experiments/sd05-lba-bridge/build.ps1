# SD-05 isolated Gowin build only, never SRAM/Flash, no SD card writes.
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$exp=Split-Path -Parent $here
$sd03=Join-Path $exp 'sd-mbr-fat32'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path -LiteralPath $gw -PathType Leaf)){throw "Missing Gowin CLI: $gw"}
& (Join-Path $here 'test.ps1')
if(-not $?) {throw 'Offline gate failed'}
$job=Join-Path $here ('build\run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
$work=Join-Path $job 'work'
New-Item -Path (Join-Path $work 'rtl'),(Join-Path $work 'constraints') -ItemType Directory -Force | Out-Null
foreach($f in @('spi_byte.v','sd_read_sector.v','uart_tx_8n1.v')){
 Copy-Item -LiteralPath (Join-Path $sd03 "rtl\$f") -Destination (Join-Path $work "rtl\$f")
}
foreach($f in @('uart_rx_8n1.v','sd05_lba_bridge_top.v')){
 Copy-Item -LiteralPath (Join-Path $here "rtl\$f") -Destination (Join-Path $work "rtl\$f")
}
Copy-Item -LiteralPath (Join-Path $sd03 'constraints\sd03_nano9k.sdc') -Destination (Join-Path $work 'constraints\sd03_nano9k.sdc')
Copy-Item -LiteralPath (Join-Path $here 'constraints\sd05_nano9k.cst') -Destination (Join-Path $work 'constraints\sd05_nano9k.cst')
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination (Join-Path $work 'build.tcl')
Get-ChildItem -LiteralPath $work -Recurse -File|Sort-Object FullName|ForEach-Object {
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
}|Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -Encoding utf8 -NoTypeInformation
Push-Location $work
try { & $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log'); $code=$LASTEXITCODE } finally {Pop-Location}
if($code -ne 0){throw "Gowin error $code, log: $(Join-Path $job 'gowin_cli.log')"}
$fs=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'sd05_lba_bridge_nano9k.fs')
if($fs.Count -ne 1){throw "Expected one fs, got $($fs.Count)"}
$bit=Join-Path $job 'sd05_lba_bridge_nano9k.fs'
Copy-Item -LiteralPath $fs[0].FullName -Destination $bit
Write-Host "SD05_BITSTREAM_CANDIDATE: $bit"
Write-Host "SD05_SHA256: $((Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash)"
Get-ChildItem -LiteralPath $work -Recurse -File|Where-Object {$_.Name -match '\.rpt\.txt$|_tr_content\.html$|\.log$'}|ForEach-Object {Write-Host "SD05_REPORT: $($_.FullName)"}
Write-Host 'SD05_BUILD_ONLY: no programming; require STA and UART RX protocol simulation before board experiment'
