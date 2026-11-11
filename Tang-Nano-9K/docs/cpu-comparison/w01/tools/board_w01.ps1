#requires -Version 7.0
<#
W01 - SHA locked, SRAM only, one CPU per invocation.
Existing accepted LAB-06 CPU bitstreams are not touched.
Without -Program this command is only a provenance/STA dry-run.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][ValidateSet('pico','neo')][string]$Cpu,
  [switch]$Program,
  [string]$Port='COM10',
  [ValidateRange(5,90)][int]$CaptureSeconds=30,
  [ValidateRange(1,8)][int]$CableIndex=1
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$w01=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo=(Resolve-Path (Join-Path $w01 '..\..\..')).Path
$fit=Join-Path $w01 '_build\fit_20261027_051220_362_32058f'
$top='w01_'+$Cpu+'_nano9k'
$fs=Join-Path $fit ($Cpu+'\'+$top+'.fs')
$fitJson=Join-Path $fit 'receipt.json'
$auditJson=Join-Path $fit ($Cpu+'\pnr_audit.json')
$programmer=Join-Path $repo '01-PicoRV32\lab04\tools\program_lab04_sram.ps1'
$capture=Join-Path $w01 'tools\capture_w01_uart.py'
$expected=if($Cpu -eq 'pico'){
 '213D90E9A6EA8BF3A6328FEB23344F35BDD31755CF709279E7977B06F18BE3FA'
}else{
 'D6C489C08158EFA92EB89A244A3D9637670737F86A8CDB871EFDB1328D10E438'
}
foreach($file in @($fs,$fitJson,$auditJson,$programmer,$capture)){
 if(-not(Test-Path -LiteralPath $file -PathType Leaf)){throw "W01_REQUIRED_FILE_MISSING: $file"}
}
if((Split-Path $fs -Leaf) -cne ($top+'.fs')){throw 'W01_FILENAME_FAIL'}
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if($sha -cne $expected){throw "W01_IMAGE_SHA_FAIL: $sha"}
$f=Get-Content $fitJson -Raw -Encoding utf8|ConvertFrom-Json
if($f.Stage -cne 'W01_FIT' -or $f.Status -cne 'BOTH_FIT_SCREEN_PASS'){throw 'W01_FIT_NOT_PASS'}
$entry=if($Cpu -eq 'pico'){$f.Pico}else{$f.Neo}
if([string]$entry.SHA256 -cne $expected){throw 'W01_FIT_RECEIPT_SHA_FAIL'}
if((Resolve-Path -LiteralPath ([string]$entry.FS)).Path -cne
   (Resolve-Path -LiteralPath $fs).Path){throw 'W01_FIT_RECEIPT_FILE_FAIL'}
$a=Get-Content $auditJson -Raw -Encoding utf8|ConvertFrom-Json
if($a.design -cne $top -or $a.bitstream_sha256 -cne $expected -or
   $a.status -cne 'PNR_PREBOARD_SCREEN_PASS_NOT_FULL_TIMING_SIGNOFF'){
 throw 'W01_PNR_AUDIT_NOT_PASS'
}
if(@($a.pins.PSObject.Properties).Count -ne 10 -or
   [double]$a.sta.slacks_ns.setup -le 0 -or
   [double]$a.sta.slacks_ns.hold -le 0 -or
   [int]$a.sta.counts.'Numbers of Setup Violated Endpoints' -ne 0 -or
   [int]$a.sta.counts.'Numbers of Hold Violated Endpoints' -ne 0){
 throw 'W01_STA_OR_PIN_SCREEN_FAIL'
}
if($Cpu -eq 'pico'){
 foreach($type in @('recovery','removal')){
  if([string]$a.sta.categories.$type -cne 'NO_ANALYZED_PATHS_RESET_NOT_QUALIFIED'){
   throw 'W01_PICO_RESET_STA_CLASS_CHANGED'
  }
 }
}else{
 foreach($type in @('recovery','removal')){
  if([string]$a.sta.categories.$type -cne 'EVALUATED_POSITIVE'){
   throw 'W01_NEO_RESET_STA_CLASS_CHANGED'
  }
 }
}
$simReceipt=Join-Path ([string]$f.SimJob) 'receipt.json'
if((Get-FileHash -LiteralPath $simReceipt -Algorithm SHA256).Hash -cne
   [string]$f.SimReceiptSHA256){throw 'W01_SIM_RECEIPT_HASH_CHANGED'}
Write-Host ('W01_'+$Cpu+'_EXACT_IMAGE_SHA_PASS: '+$sha) -ForegroundColor Green
Write-Host ('W01_'+$Cpu+'_FILE: '+$fs)
Write-Host 'W01_PNR_PINS_SETUP_HOLD_PASS: NOT a full external timing sign-off'
if($Cpu -eq 'pico'){
 Write-Host 'W01_RESET_CAVEAT: Recovery/Removal have no analyzed paths; single lab smoke only.' -ForegroundColor Yellow
}
if(-not $Program){
 Write-Host ('W01_'+$Cpu+'_DRY_RUN_ONLY: no FPGA actions. Use -Program after review.')
 return
}
if(-not(Get-Command python -ErrorAction SilentlyContinue)){throw 'W01_PYTHON_NOT_FOUND'}
& python -c 'import serial'
if($LASTEXITCODE -ne 0){throw 'W01_PYSERIAL_NOT_FOUND'}
$board=Join-Path $w01 ('_build\board_'+$Cpu+'_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item $board -ItemType Directory -Force|Out-Null
$json=Join-Path $board 'board_receipt.json'
$uart=Join-Path $board 'uart.json'
$raw=Join-Path $board 'uart_raw.bin'
$log=Join-Path $board 'uart.log'
$receipt=[ordered]@{
 Cpu=$Cpu;FitJob=$fit;Bitstream=$fs;SHA256=$sha;Port=$Port
 Program='NOT_RUN';UART='NOT_RUN';Cycles=$null
 LEDs='OPERATOR_CONFIRMATION_PENDING';Board='NOT_ACCEPTED'
 Reset='NOT_FULLY_QUALIFIED';Flash='NOT_TOUCHED';SD='NOT_TOUCHED'
 CaptureJson=$uart;CaptureLog=$log
}
function Save-BoardReceipt {
 $receipt|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $json -Encoding utf8
}
Save-BoardReceipt
try{
 & $programmer -Bitstream $fs -Program -CableIndex $CableIndex
 $receipt.Program='PASS'
 Save-BoardReceipt
 Write-Host ('W01_'+$Cpu+'_SRAM_PROGRAM_PASS') -ForegroundColor Green
}catch{
 $receipt.Program='FAIL'
 Save-BoardReceipt
 throw
}
Write-Host 'W01_UART_NEXT: when Python opens COM port, press S1 once.'
& python -u $capture --cpu $Cpu --port $Port --seconds $CaptureSeconds --raw $raw --json $uart *>&1 |
 Tee-Object -FilePath $log
$exitCode=$LASTEXITCODE
if($exitCode -eq 0){
 $c=Get-Content $uart -Raw -Encoding utf8|ConvertFrom-Json
 if($c.status -cne 'UART_PASS_LED_PENDING' -or $c.digest -cne 'B26F8CA7' -or
    $c.cpu -cne $Cpu){throw 'W01_INVALID_UART_RECEIPT'}
 $receipt.UART='PASS'
 $receipt.Cycles=[int]$c.cycles
 $receipt.Board='UART_PASS_LED_PENDING'
 Write-Host ('W01_'+$Cpu+'_CYCLES: '+$c.cycles) -ForegroundColor Green
}else{
 $receipt.UART='FAIL'
}
Save-BoardReceipt
Write-Host ('W01_'+$Cpu+'_BOARD_RECEIPT: '+$json)
Write-Host 'W01_LED_CHECK: confirm three lit LEDs physically; do not claim full STA sign-off.'
if($exitCode -ne 0){throw 'W01_UART_FAIL'}
