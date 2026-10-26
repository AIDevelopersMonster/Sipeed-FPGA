#requires -Version 7.0
<#
LAB-06.2B -- Pin-locked PicoRV32 real-CPU Gowin PnR/STA candidate.
Requires operator-proven exact LAB062 SIM PASS first.
- Reads exact ROM from the passed simulation job.
- Verifies pinned upstream CPU, prior vvp log, ROM SHA and every source SHA.
- Stages all sources in a NEW isolated work directory; does not touch LAB04.
- Builds for Tang Nano 9K via Gowin CLI (NOT Gowin Programmer).
- Never writes FPGA SRAM, configuration Flash, or SD.
Example (only after sim PASS):
  .\01-PicoRV32\lab06\tools\fit_lab062.ps1 -SimJob '.\01-PicoRV32\lab06\_build\run_YYYYMMDD_HHMMSS'
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $SimJob,
  [string] $GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$lab = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$pico = (Resolve-Path -LiteralPath (Join-Path $lab '..')).Path
$vendor = Join-Path $pico 'vendor\picorv32'
$sourcePin = 'ef203c2b0a3fb793280f5114941416c425c5b461'
$cpuFile = Join-Path $vendor 'picorv32.v'
$gowin = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
foreach($required in @('git','python')){
  if (-not (Get-Command $required -ErrorAction SilentlyContinue)) {
    throw "LAB062_MISSING_TOOL: $required"
  }
}
if (-not (Test-Path -LiteralPath $gowin -PathType Leaf)) {
  throw "LAB062_GOWIN_CLI_MISSING: $gowin"
}
if (-not (Test-Path -LiteralPath $cpuFile -PathType Leaf)) {
  throw 'LAB062_VENDOR_NOT_FOUND: run 01-PicoRV32/tools/fetch_picorv32.ps1'
}
$rev = (& git -C $vendor rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or ([string]$rev).Trim() -cne $sourcePin) {
  throw "LAB062_CPU_PIN_MISMATCH: $rev"
}
$dirty = @(& git -C $vendor status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) {
  throw 'LAB062_VENDOR_TRACKED_MODIFIED: stop'
}

$sim = (Resolve-Path -LiteralPath $SimJob -ErrorAction Stop).Path
$simReceipt = Join-Path $sim 'receipt.json'
$simLog = Join-Path $sim 'vvp.log'
$rom = Join-Path $sim 'lab062_boot.hex'
$bin = Join-Path $sim 'lab062.bin'
foreach($path in @($simReceipt,$simLog,$rom,$bin)){
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "LAB062_SIM_EVIDENCE_MISSING: $path"
  }
}
$r = Get-Content -LiteralPath $simReceipt -Raw -Encoding utf8 | ConvertFrom-Json
if ($r.Stage -cne 'LAB062_A' -or $r.UpstreamCommit -cne $sourcePin -or
    $r.Simulation -cne 'PASS' -or $r.ROMBytes -ne 16384 -or
    $r.RAMBytes -ne 2048 -or $r.ClockHz -ne 27000000 -or
    $r.Isa -cne 'rv32i') {
  throw 'LAB062_SIM_RECEIPT_NOT_ACCEPTED: SIM PASS and parameters required'
}
if (-not (Select-String -LiteralPath $simLog -SimpleMatch 'LAB062_PICORV32_UART_GPIO_TB_PASS' -Quiet)) {
  throw 'LAB062_SIM_LOG_MISSING_UART_GPIO_PASS'
}
foreach($artifact in @(
  @{ Path = $rom; Hash = [string]$r.ROMSHA256; Label='ROM' },
  @{ Path = $bin; Hash = [string]$r.FirmwareSHA256; Label='BINARY' }
)){
  $actual = (Get-FileHash -LiteralPath $artifact.Path -Algorithm SHA256).Hash
  if ($actual -cne $artifact.Hash) {
    throw "LAB062_$($artifact.Label)_SHA256_FAIL: $actual != $($artifact.Hash)"
  }
}
if (@(Get-Content -LiteralPath $rom).Count -ne 4096) {
  throw 'LAB062_ROM_LENGTH_FAIL: 4096 words expected'
}
foreach($inputFile in @($r.Inputs)) {
  $path = [string]$inputFile.Path
  if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
    throw "LAB062_SIM_SOURCE_NOT_FOUND: $path"
  }
  $actual=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
  if ($actual -cne [string]$inputFile.SHA256) {
    throw "LAB062_SIM_SOURCE_CHANGED: $path"
  }
}

$job = Join-Path $lab ('_build\fit_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') +
                      '_' + [guid]::NewGuid().ToString('N').Substring(0,6))
$work = Join-Path $job 'work'
$rtlDir = Join-Path $work 'rtl'
$cstDir = Join-Path $work 'constraints'
New-Item -ItemType Directory -Force -Path $rtlDir,$cstDir | Out-Null
Write-Host "LAB062_FIT_JOB: $job"
Write-Host "LAB062_SOURCE_PIN_PASS: $sourcePin"
Write-Host "LAB062_SIM_EVIDENCE_PASS: $simReceipt"
Write-Host "LAB062_SIM_ROM_SHA256_PASS: $($r.ROMSHA256)"
Write-Host 'LAB062_NO_FPGA_ACTION: Gowin fit only; no programmer, Flash or SD'

$rtlSources = @(
  $cpuFile,
  (Join-Path $pico 'rtl\uart_tx_8n1.v'),
  (Join-Path $pico 'rtl\uart_rx_8n1.v'),
  (Join-Path $lab 'rtl\lab062_pico_soc.v')
)
foreach($source in $rtlSources) {
  $dest = Join-Path $rtlDir (Split-Path -Path $source -Leaf)
  Copy-Item -LiteralPath $source -Destination $dest
}
Copy-Item -LiteralPath $rom -Destination (Join-Path $work 'lab062_boot.hex')
foreach($name in @('lab062_nano9k.cst','lab062_nano9k.sdc')) {
  Copy-Item -LiteralPath (Join-Path $lab "constraints\$name") -Destination $cstDir
}
$stagedInputList = @(
  Get-ChildItem -LiteralPath $work -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
      [pscustomobject]@{
        Path=$_.FullName.Substring($work.Length+1).Replace('\','/')
        SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
      }
    }
)
$stagedInputList | Export-Csv -LiteralPath (Join-Path $job 'inputs_sha256.csv') -Encoding utf8 -NoTypeInformation
if ($stagedInputList.Count -ne 7) {
  throw "LAB062_STAGE_COUNT_FAIL: $($stagedInputList.Count); expected 4 Verilog + ROM + CST + SDC"
}

$tcl = Join-Path $work 'gowin_fit.tcl'
@'
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/lab062_nano9k.cst
add_file constraints/lab062_nano9k.sdc
add_file rtl/picorv32.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file rtl/lab062_pico_soc.v
set_option -top_module lab062_pico_soc
set_option -output_base_name lab062_pico_nano9k
set_option -synthesis_tool gowinsynthesis
run all
'@ | Set-Content -LiteralPath $tcl -Encoding utf8

$gowinLog = Join-Path $job 'gowin_cli.log'
Push-Location $work
try {
  & $gowin 'gowin_fit.tcl' *> $gowinLog
  $gowinExit = $LASTEXITCODE
} finally { Pop-Location }
Write-Host "LAB062_GOWIN_LOG: $gowinLog"
if ($gowinExit -ne 0) {
  Get-Content -LiteralPath $gowinLog -Tail 100
  throw "LAB062_GOWIN_PNR_FAIL: exit=$gowinExit"
}

$bitCandidates=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'lab062_pico_nano9k.fs')
if ($bitCandidates.Count -ne 1) {
  Get-Content -LiteralPath $gowinLog -Tail 90
  throw "LAB062_BITSTREAM_COUNT_FAIL: $($bitCandidates.Count)"
}
$bit=Join-Path $job 'lab062_pico_nano9k.fs'
Copy-Item -LiteralPath $bitCandidates[0].FullName -Destination $bit
$bitSHA=(Get-FileHash -LiteralPath $bit -Algorithm SHA256).Hash
Write-Host "LAB062_PNR_BITSTREAM_CANDIDATE: $bit"
Write-Host "LAB062_BITSTREAM_SHA256: $bitSHA"

$reports=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter '*_tr_content.html')
if ($reports.Count -ne 1) {
  throw "LAB062_STA_REPORT_COUNT_FAIL: $($reports.Count); DO NOT PROGRAM"
}
$sta = $reports[0].FullName
$staLog=Join-Path $job 'sta_audit.log'
& python (Join-Path $lab 'tools\check_sta_lab062.py') $sta --log $gowinLog *> $staLog
$staExit = $LASTEXITCODE
Get-Content -LiteralPath $staLog -Tail 35
$reportTxt=Join-Path $work 'impl\pnr\lab062_pico_nano9k.rpt.txt'
if (-not (Test-Path -LiteralPath $reportTxt -PathType Leaf)) {
  throw "LAB062_RESOURCE_REPORT_MISSING: $reportTxt"
}
Write-Host "LAB062_RESOURCE_REPORT: $reportTxt"
Get-Content -LiteralPath $reportTxt |
  Select-String -Pattern '^\s*(Logic|Register|I/O Port|BSRAM|DSP|PLL)\s+\|' |
  Select-Object -First 16 |
  ForEach-Object { Write-Host $_.Line }

$fitReceipt=[ordered]@{
  Stage='LAB062_FIT'
  DateUtc=(Get-Date).ToUniversalTime().ToString('o')
  UpstreamCommit=$sourcePin
  SimJob=$sim
  SimReceiptSHA256=(Get-FileHash -LiteralPath $simReceipt -Algorithm SHA256).Hash
  SimStatus='PASS'
  ClockHz=27000000
  RomBytes=16384
  RamBytes=2048
  RomSHA256=[string]$r.ROMSHA256
  BinarySHA256=[string]$r.FirmwareSHA256
  GowinDevice='GW1NR-9C GW1NR-LV9QN88PC6/I5'
  BitstreamCandidateSHA256=$bitSHA
  TimingHtml=$sta
  ReportText=$reportTxt
  StaScreen=if($staExit -eq 0){'PRELIM_PASS'}else{'FAIL_OR_INCOMPLETE'}
  PnR='PASS'
  PinVccio='NOT_AUDITED'
  Board='NOT_RUN'
}
$fitReceipt | ConvertTo-Json -Depth 8 |
  Set-Content -LiteralPath (Join-Path $job 'fit_receipt.json') -Encoding utf8
if($staExit -ne 0) {
  throw "LAB062_STA_SCREEN_FAIL: $staLog; DO NOT PROGRAM"
}
Write-Host "LAB062_FIT_STA_PRELIM_PASS: resource/pin audit still required; NO BOARD PROGRAMMING" -ForegroundColor Green
Write-Host "LAB062_FIT_RECEIPT: $(Join-Path $job 'fit_receipt.json')"
Write-Host 'LAB062_BOARD_NOT_RUN: Gowin Programmer not invoked, no FPGA SRAM, Flash or SD access.'
