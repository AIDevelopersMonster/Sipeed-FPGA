# Offline validated one-sector bitstream build, DOES NOT PROGRAM FPGA.
# Must derive sector from scratch_gate inspect's pinned manifest.
param(
 [Parameter(Mandatory=$true)][string]$Manifest,
 [Parameter(Mandatory=$true)][string]$Backup,
 [string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$root=(Resolve-Path (Join-Path $here '..\..\..\..')).Path
$sd03=Join-Path $root 'boards\tang-nano-9k\experiments\sd-mbr-fat32'
$sd05=Join-Path $root 'boards\tang-nano-9k\experiments\sd05-lba-bridge'
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path $gw)){throw "Gowin missing: $gw"}
$manifestPath=(Resolve-Path -LiteralPath $Manifest).Path
$backupPath=(Resolve-Path -LiteralPath $Backup).Path
& python (Join-Path $here 'tools\scratch_gate.py') validate --manifest $manifestPath --backup $backupPath
if($LASTEXITCODE -ne 0){throw 'Scratch manifest/backup invalid'}
$doc=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
[uint64]$lba=$doc.scratch_lba
if($lba -lt 1 -or $lba -ge 4294967295){throw 'Unsafe LBA'}
$job=Join-Path $here ('build\scratch_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$work=Join-Path $job 'work'
foreach($folder in @('rtl','constraints')){
 New-Item -ItemType Directory -Force (Join-Path $work $folder)|Out-Null
}
foreach($file in @('spi_byte.v','sd_read_sector.v','uart_tx_8n1.v')){
 Copy-Item (Join-Path $sd03 "rtl\$file") (Join-Path $work "rtl\$file")
}
Copy-Item (Join-Path $sd05 'rtl\uart_rx_8n1.v') (Join-Path $work 'rtl\uart_rx_8n1.v')
foreach($file in @('sd06_cmd24_engine.v','sd06_rw_bridge_top.v')){
 Copy-Item (Join-Path $here "rtl\$file") (Join-Path $work "rtl\$file")
}
Copy-Item (Join-Path $sd05 'constraints\sd05_nano9k.cst') (Join-Path $work 'constraints\sd_rw.cst')
Copy-Item (Join-Path $sd03 'constraints\sd03_nano9k.sdc') (Join-Path $work 'constraints\sd_rw.sdc')
Copy-Item (Join-Path $here 'build_scratch.tcl') (Join-Path $work 'build_scratch.tcl')
$wrapper=@"
module sd06_scratch_top(
 input wire clk,reset_n,uart_rx,sd_miso,
 output wire uart_tx,sd_sck,sd_mosi,sd_cs_n,
 output wire [5:0] led_n
);
sd06_rw_bridge_top #(
 .WRITE_FIRST_LBA(32'd$lba),.WRITE_LAST_LBA(32'd$lba)
) u_main(.clk(clk),.reset_n(reset_n),.uart_rx(uart_rx),
 .sd_miso(sd_miso),.uart_tx(uart_tx),.sd_sck(sd_sck),
 .sd_mosi(sd_mosi),.sd_cs_n(sd_cs_n),.led_n(led_n));
endmodule
"@
Set-Content -LiteralPath (Join-Path $work 'rtl\sd06_scratch_top.v') -Value $wrapper -Encoding ascii
Copy-Item $manifestPath (Join-Path $job 'manifest.json')
Get-ChildItem $work -Recurse -File|Sort-Object FullName|ForEach-Object{
 [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash $_.FullName).Hash}
}|Export-Csv (Join-Path $job 'inputs.csv') -NoTypeInformation
Write-Host "SD_RW_SCRATCH_BUILD: FPGA WRITE PERMISSION ONLY LBA=$lba"
Write-Host 'DO NOT PROGRAM until disposable FAT32 scratch card and real COM preflight verified'
Push-Location $work
try{& $gw 'build_scratch.tcl' *> (Join-Path $job 'gowin_cli.log');$exitcode=$LASTEXITCODE}finally{Pop-Location}
if($exitcode -ne 0){throw "Gowin build error; inspect $job\gowin_cli.log"}
$reports=@(Get-ChildItem $work -Recurse -File -Filter '*tr_content.html')
if($reports.Count -ne 1){throw 'STA report missing or ambiguous'}
# Require zero violations in parsed summary without inventing margins.
$html=Get-Content -LiteralPath $reports[0].FullName -Raw
if($html -notmatch 'Numbers of Setup Violated Endpoints</td>\s*<td>0</td>' -or
 $html -notmatch 'Numbers of Hold Violated Endpoints</td>\s*<td>0</td>'){
 throw "Timing acceptance not established; inspect $($reports[0].FullName)"
}
$fs=@(Get-ChildItem $work -Recurse -File -Filter 'sd06_scratch_SINGLE_SECTOR.fs')
if($fs.Count -ne 1){throw 'Expected one scratch bitstream'}
$dest=Join-Path $job 'sd06_scratch_SINGLE_SECTOR.fs'
Copy-Item $fs[0].FullName $dest
Write-Host "SD_RW_SCRATCH_BUILD_STA_PASS: LBA=$lba"
Write-Host "SD_RW_SCRATCH_BITSTREAM: $dest"
Write-Host "SD_RW_SCRATCH_SHA256: $((Get-FileHash $dest).Hash)"
Write-Host "SD_RW_SCRATCH_REPORT: $($reports[0].FullName)"
Write-Host 'NO BOARD PROGRAMMING. NO SD WRITES.'
