# Resource/STA study with write datapath retained. NO bitstream delivery.
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$root=(Resolve-Path (Join-Path $here '..\..\..\..')).Path
$sd05=Join-Path $root 'boards\tang-nano-9k\experiments\sd05-lba-bridge'
$sd03=Join-Path $root 'boards\tang-nano-9k\experiments\sd-mbr-fat32'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path -LiteralPath $gw -PathType Leaf)){throw "Gowin missing: $gw"}
$job=Join-Path $here ('build\measurement_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$work=Join-Path $job 'work'
foreach($folder in @('rtl','constraints')){New-Item -ItemType Directory -Force -Path (Join-Path $work $folder)|Out-Null}
foreach($f in @('spi_byte.v','sd_read_sector.v','uart_tx_8n1.v')){
 Copy-Item -LiteralPath (Join-Path $sd03 "rtl\$f") -Destination (Join-Path $work "rtl\$f")
}
Copy-Item -LiteralPath (Join-Path $sd05 'rtl\uart_rx_8n1.v') -Destination (Join-Path $work 'rtl\uart_rx_8n1.v')
foreach($f in @('sd06_cmd24_engine.v','sd06_rw_bridge_top.v','sd06_rw_measure_top.v')){
 Copy-Item -LiteralPath (Join-Path $here "rtl\$f") -Destination (Join-Path $work "rtl\$f")
}
Copy-Item -LiteralPath (Join-Path $sd05 'constraints\sd05_nano9k.cst') -Destination (Join-Path $work 'constraints\sd_rw.cst')
Copy-Item -LiteralPath (Join-Path $sd03 'constraints\sd03_nano9k.sdc') -Destination (Join-Path $work 'constraints\sd_rw.sdc')
Copy-Item -LiteralPath (Join-Path $here 'build_measure.tcl') -Destination (Join-Path $work 'build_measure.tcl')
Get-ChildItem $work -Recurse -File|Sort-Object FullName|ForEach-Object{
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash $_.FullName).Hash}
}|Export-Csv (Join-Path $job 'inputs.csv') -NoTypeInformation
Write-Host 'SD_RW_MEASURE_ONLY: hypothetical LBA FFFFFFFE enables RTL retention; NEVER load result on board.'
$code=1
Push-Location $work
try{& $gw 'build_measure.tcl' *> (Join-Path $job 'gowin_cli.log');$code=$LASTEXITCODE}
finally{Pop-Location}
# Remove *every* programming artifact before even reporting compilation outcome.
Get-ChildItem -LiteralPath $job -Recurse -File |
  Where-Object{$_.Extension -in @('.fs','.bin','.mcs','.jed','.bit')} |
  Remove-Item -Force
if($code -ne 0){throw "Gowin failed: $job\gowin_cli.log"}
Write-Host "SD_RW_MEASURE_DIR: $job"
$reports=@(Get-ChildItem -LiteralPath $work -Recurse -File|
  Where-Object{$_.Name -match 'tr_content|\.rpt\.txt$|_stat\.html$|_rpt\.html$'})
$reports|Select-Object -ExpandProperty FullName
Write-Host "SD_RW_MEASURE_PASS: Gowin exited 0; NO programming artifacts retained; read STA/resource reports."
