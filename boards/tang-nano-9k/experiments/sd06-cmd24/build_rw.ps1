# Isolated Gowin candidate, WRITE_FIRST_LBA = WRITE_LAST_LBA = 0.
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$root=(Resolve-Path (Join-Path $here '..\..\..\..')).Path
$sd05=Join-Path $root 'boards\tang-nano-9k\experiments\sd05-lba-bridge'
$sd03=Join-Path $root 'boards\tang-nano-9k\experiments\sd-mbr-fat32'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path $gw)){throw "Missing Gowin: $gw"}
$job=Join-Path $here ('build\rw_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$work=Join-Path $job 'work'
foreach($folder in @('rtl','constraints')){
 New-Item -Force -ItemType Directory -Path (Join-Path $work $folder)|Out-Null
}
foreach($f in @('spi_byte.v','sd_read_sector.v','uart_tx_8n1.v')){
 Copy-Item (Join-Path $sd03 "rtl\$f") (Join-Path $work "rtl\$f")
}
Copy-Item (Join-Path $sd05 'rtl\uart_rx_8n1.v') (Join-Path $work 'rtl\uart_rx_8n1.v')
foreach($f in @('sd06_cmd24_engine.v','sd06_rw_bridge_top.v')){
 Copy-Item (Join-Path $here "rtl\$f") (Join-Path $work "rtl\$f")
}
Copy-Item (Join-Path $sd05 'constraints\sd05_nano9k.cst') (Join-Path $work 'constraints\sd_rw.cst')
Copy-Item (Join-Path $sd03 'constraints\sd03_nano9k.sdc') (Join-Path $work 'constraints\sd_rw.sdc')
Copy-Item (Join-Path $here 'build_rw.tcl') (Join-Path $work 'build_rw.tcl')
Get-ChildItem $work -Recurse -File|Sort-Object FullName|ForEach-Object{
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash $_.FullName).Hash}
}|Export-Csv (Join-Path $job 'inputs.csv') -NoTypeInformation
Write-Host 'WRITE_REGION_DISABLED: 0..0'
Push-Location $work
try{& $gw 'build_rw.tcl' *> (Join-Path $job 'gowin_cli.log');$code=$LASTEXITCODE}finally{Pop-Location}
if($code -ne 0){throw "Gowin error $code, log $job\gowin_cli.log"}
$fs=@(Get-ChildItem $work -Recurse -Filter 'sd06_rw_nano9k.fs' -File)
if($fs.Count -ne 1){throw "Expected one bitstream, found $($fs.Count)"}
$dest=Join-Path $job 'sd06_rw_nano9k.fs'
Copy-Item $fs[0].FullName $dest
Write-Host "SD_RW_CANDIDATE_ONLY: $dest"
Write-Host "SD_RW_SHA256: $((Get-FileHash $dest -Algorithm SHA256).Hash)"
Get-ChildItem $work -Recurse -File|Where-Object{$_.Name -match 'tr_content|\.rpt\.txt$'}|Select-Object -ExpandProperty FullName
Write-Host 'NO FPGA PROGRAMMING. STA AND FULL UART SIMULATION NOT YET ACCEPTED.'
