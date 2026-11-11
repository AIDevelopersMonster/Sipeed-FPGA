# Qualified next hardware gate: merged RW board design, WRITE LOCKED OFF.
# Builds fresh isolated .fs; optional explicit SRAM-only programming and CMD17.
# Never writes SD sectors; never programs flash.
param(
 [string]$Port='COM10',
 [int]$Lba=0,
 [switch]$Program,
 [string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$root=(Resolve-Path (Join-Path $here '..\..\..\..')).Path
if($Lba -lt 0){throw 'LBA must be >= 0'}
Write-Host 'SD_RW_GATE: READ-ONLY HARDWARE; WRITE_FIRST_LBA=0 WRITE_LAST_LBA=0'
Write-Host 'SD_RW_GATE: no physical SD writing and no FPGA flash programming'
& (Join-Path $here 'test.ps1')
if($LASTEXITCODE -ne 0){throw 'Offline regression gate failed'}
& (Join-Path $here 'build_rw.ps1') -GowinRoot $GowinRoot
if($LASTEXITCODE -ne 0){throw 'Gowin read-only build failed'}
$builds=@(Get-ChildItem -LiteralPath (Join-Path $here 'build') -Directory|
 Where-Object{$_.Name -like 'rw_*'}|Sort-Object LastWriteTime -Descending)
if($builds.Count -eq 0){throw 'No RW build directory was generated'}
$job=$builds[0].FullName
$fs=Join-Path $job 'sd06_rw_nano9k.fs'
if(-not(Test-Path -LiteralPath $fs)){throw "No bitstream at $fs"}
$report=Join-Path $job 'work\impl\pnr\sd06_rw_nano9k_tr_content.html'
if(-not(Test-Path -LiteralPath $report)){throw 'STA HTML missing'}
$timing=Get-Content -LiteralPath $report -Raw
if($timing -notmatch 'Numbers of Setup Violated Endpoints</td>\s*<td>0</td>' -or
   $timing -notmatch 'Numbers of Hold Violated Endpoints</td>\s*<td>0</td>'){
 throw "Setup/hold timing not proven: $report"
}
$hash=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "SD_RW_READ_ONLY_BUILD_AND_STA_PASS: $fs"
Write-Host "SD_RW_READ_ONLY_SHA256: $hash"
if(-not $Program){
 Write-Host 'SD_RW_READ_ONLY_DRY_RUN_PASS: nothing programmed. Re-run -Program for SRAM+read.'
 return
}
$prog=Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
if(-not(Test-Path -LiteralPath $prog)){throw "Programmer CLI missing: $prog"}
Write-Host "PROGRAMMING SRAM ONLY: $fs"
& $prog --device GW1NR-9C --operation_index 2 --fsFile $fs --cable-index 1
if($LASTEXITCODE -ne 0){throw "SRAM programming failed: $LASTEXITCODE"}
$out=Join-Path $job ("read_LBA_{0}.bin" -f $Lba)
$client=Join-Path $here 'tools\sd_rw.py'
& python $client --port $Port read --lba $Lba --out $out
if($LASTEXITCODE -ne 0){throw 'SD RW read-only hardware gate failed'}
if((Get-Item -LiteralPath $out).Length -ne 512){throw 'Sector not 512 bytes'}
Write-Host "SD_RW_READ_ONLY_HARDWARE_PASS: $out"
Write-Host "SD_RW_READ_ONLY_SHA256: $((Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash)"
