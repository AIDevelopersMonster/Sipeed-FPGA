#requires -Version 7.0
<#
W01 final dual native-SoC Gowin PnR (Tang Nano 9K).
Gate: both REAL CPU simulations PASS, matched exact RISC-V binary digests.
No Gowin Programmer, USB/JTAG, SRAM, Flash or SD actions.
Usage: .\docs\cpu-comparison\w01\tools\fit_w01.ps1 -SimJob <sim_*>
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $SimJob,
  [string] $GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$w01 = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$repo = (Resolve-Path -LiteralPath (Join-Path $w01 '..\..\..')).Path
$sim = (Resolve-Path -LiteralPath $SimJob -ErrorAction Stop).Path
$simReceiptPath = Join-Path $sim 'receipt.json'
$simR = Get-Content -LiteralPath $simReceiptPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($simR.Stage -cne 'W01_SIM' -or $simR.Status -cne 'BOTH_SIM_PASS') {
  throw 'W01_SIM_PASS_REQUIRED: no Gowin fit'
}
$compReceiptPath = Join-Path ([string]$simR.CompileJob) 'receipt.json'
$compSHA = (Get-FileHash -LiteralPath $compReceiptPath -Algorithm SHA256).Hash
if ($compSHA -cne [string]$simR.CompileReceiptSHA256) {
  throw 'W01_COMPILE_RECEIPT_CHANGED'
}
$compR = Get-Content -LiteralPath $compReceiptPath -Raw | ConvertFrom-Json
if ($compR.Stage -cne 'W01_COMPILER' -or
    $compR.Status -cne 'COMPILE_PASS_SIM_NOT_RUN' -or
    $compR.WorkloadInstructionWords -ne 62) {
  throw 'W01_COMPILE_PROVENANCE_FAIL'
}
foreach ($cpu in @('pico','neo')) {
  $log = if ($cpu -eq 'pico') { [string]$simR.PicoSimLog } else { [string]$simR.NeoSimLog }
  $marker = 'W01_' + $cpu.ToUpperInvariant() + '_SIM_PASS digest=B26F8CA7'
  if (-not (Select-String -LiteralPath $log -SimpleMatch $marker -Quiet)) {
    throw ('W01_REAL_CPU_SIM_LOG_MISSING: ' + $cpu)
  }
  $input = if ($cpu -eq 'pico') { $compR.Pico } else { $compR.Neo }
  $sha = (Get-FileHash -LiteralPath ([string]$input.Bin) -Algorithm SHA256).Hash
  if ($sha -cne [string]$input.SHA256) { throw ('W01_BINARY_HASH_CHANGED: ' + $cpu) }
}
if ((Get-FileHash -LiteralPath ([string]$simR.PicoROM) -Algorithm SHA256).Hash -cne
    [string]$simR.PicoRomSHA256) { throw 'W01_PICO_SIM_ROM_HASH_CHANGED' }
if ((Get-FileHash -LiteralPath ([string]$simR.NeoIMEM) -Algorithm SHA256).Hash -cne
    [string]$simR.NeoImemSHA256) { throw 'W01_NEO_SIM_IMEM_HASH_CHANGED' }
foreach ($tool in @('git', 'ghdl', 'python')) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw ('W01_MISSING_TOOL: ' + $tool)
  }
}
$gowin = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path -LiteralPath $gowin -PathType Leaf)) { throw "W01_GOWIN_MISSING: $gowin" }
$picoVendor = Join-Path $repo '01-PicoRV32\vendor\picorv32'
$neoVendor = Join-Path $repo '02-NEORV32\_deps\neorv32'
if (([string](& git -C $picoVendor rev-parse HEAD)).Trim() -cne
    'ef203c2b0a3fb793280f5114941416c425c5b461') { throw 'W01_PICO_UPSTREAM_REV_CHANGED' }
if (([string](& git -C $neoVendor rev-parse HEAD)).Trim() -cne
    'b2620454ebb2407e81a6a1965ef52e2a860b0432') { throw 'W01_NEO_UPSTREAM_REV_CHANGED' }

# RTL was simulated at the immutable Git revision below.
# Reject local edits (including an accidentally modified prior LAB06 core).
$simCodeRevision = '6ccbbe569815121f23bcd2b3775bbd8e3d03d525'
$checked = @(
  'docs/cpu-comparison/w01/rtl/w01_pico_soc.v',
  'docs/cpu-comparison/w01/rtl/w01_neo_top.vhd',
  'docs/cpu-comparison/w01/common/w01_workload.S',
  '01-PicoRV32/rtl/uart_tx_8n1.v',
  '01-PicoRV32/rtl/uart_rx_8n1.v',
  '01-PicoRV32/lab06/constraints/lab062_nano9k.cst',
  '01-PicoRV32/lab06/constraints/lab062_nano9k.sdc',
  '02-NEORV32/constraints/lab061_nano9k.cst',
  '02-NEORV32/constraints/lab061_nano9k.sdc'
)
foreach ($relative in $checked) {
  $full = Join-Path $repo ($relative.Replace('/','\'))
  $actual = [string](& git -C $repo hash-object $full)
  $expected = [string](& git -C $repo rev-parse ($simCodeRevision + ':' + $relative))
  if ($LASTEXITCODE -ne 0 -or $actual.Trim() -cne $expected.Trim()) {
    throw ('W01_SOURCE_CHANGED_SINCE_SIM: ' + $relative)
  }
}
Write-Host 'W01_SIM_AND_SOURCE_IDENTITY_PASS: 62 equal workload words; both real CPU SIM PASS' -ForegroundColor Green

$job = Join-Path $w01 ('_build\fit_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') +
                       '_' + [guid]::NewGuid().ToString('N').Substring(0,6))
New-Item -ItemType Directory -Force -Path $job | Out-Null
Write-Host "W01_FIT_JOB: $job"
Write-Host 'W01_NO_BOARD_ACTION: two Gowin PnRs only; no FPGA/Flash/SD access'
$results = @{}
foreach ($cpu in @('pico','neo')) {
  $top = 'w01_' + $cpu + '_nano9k'
  $dir = Join-Path $job $cpu
  $work = Join-Path $dir 'work'
  $rtl = Join-Path $work 'rtl'
  $con = Join-Path $work 'constraints'
  New-Item -ItemType Directory -Force -Path $rtl,$con | Out-Null
  if ($cpu -eq 'pico') { $baseLab = '01-PicoRV32\lab06'; $tag = 'lab062' }
  else { $baseLab = '02-NEORV32'; $tag = 'lab061' }
  Copy-Item -LiteralPath (Join-Path $repo ($baseLab+'\constraints\'+$tag+'_nano9k.cst')) -Destination (Join-Path $con 'w01_nano9k.cst')
  Copy-Item -LiteralPath (Join-Path $repo ($baseLab+'\constraints\'+$tag+'_nano9k.sdc')) -Destination (Join-Path $con 'w01_nano9k.sdc')
  if ($cpu -eq 'pico') {
    Copy-Item -LiteralPath (Join-Path $picoVendor 'picorv32.v') -Destination (Join-Path $rtl 'picorv32.v')
    foreach ($name in @('uart_tx_8n1.v','uart_rx_8n1.v')) {
      Copy-Item -LiteralPath (Join-Path $repo ('01-PicoRV32\rtl\'+$name)) -Destination (Join-Path $rtl $name)
    }
    Copy-Item -LiteralPath (Join-Path $w01 'rtl\w01_pico_soc.v') -Destination (Join-Path $rtl 'w01_pico_soc.v')
    Copy-Item -LiteralPath ([string]$simR.PicoROM) -Destination (Join-Path $work 'w01_pico_boot.hex')
    $tcl = @'
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/w01_nano9k.cst
add_file constraints/w01_nano9k.sdc
add_file rtl/picorv32.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file rtl/w01_pico_soc.v
set_option -top_module w01_pico_soc
set_option -output_base_name w01_pico_nano9k
set_option -synthesis_tool gowinsynthesis
run all
'@
  } else {
    $vhdl = [System.Collections.Generic.List[string]]::new()
    $images = 0
    foreach ($entry in (Get-Content -LiteralPath (Join-Path $neoVendor 'rtl\file_list_core.f'))) {
      $entry = $entry.Trim()
      if (-not $entry -or $entry.StartsWith('#')) { continue }
      if (-not $entry.StartsWith('$NEORV32_HOME/')) { throw 'W01_NEO_SOURCE_LIST_INVALID' }
      $rel = $entry.Substring('$NEORV32_HOME/'.Length)
      if (-not $rel.StartsWith('rtl/core/') -or $rel.Contains('..')) { throw 'W01_NEO_SOURCE_LIST_PATH_INVALID' }
      $dest = Join-Path $work ($rel.Replace('/','\'))
      New-Item -ItemType Directory -Force -Path (Split-Path $dest -Parent) | Out-Null
      if ($rel -eq 'rtl/core/neorv32_imem_image.vhd') {
        $origin = [string]$simR.NeoIMEM
        $images++
      } else {
        $origin = Join-Path $neoVendor ($rel.Replace('/','\'))
      }
      Copy-Item -LiteralPath $origin -Destination $dest
      $vhdl.Add($dest)
    }
    if ($images -ne 1 -or $vhdl.Count -lt 40) { throw 'W01_NEO_VHDL_MANIFEST_FAIL' }
    $topVhd = Join-Path $rtl 'w01_neo_top.vhd'
    Copy-Item -LiteralPath (Join-Path $w01 'rtl\w01_neo_top.vhd') -Destination $topVhd
    $vhdl.Add($topVhd)
    $lib = Join-Path $dir 'ghdl'
    New-Item -ItemType Directory -Force -Path $lib | Out-Null
    & ghdl -i --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" @($vhdl.ToArray()) *> (Join-Path $dir 'ghdl_import.log')
    if ($LASTEXITCODE -ne 0) {
      Get-Content (Join-Path $dir 'ghdl_import.log') -Tail 60
      throw 'W01_NEO_GHDL_IMPORT_FAIL'
    }
    & ghdl -m --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" w01_neo_top *> (Join-Path $dir 'ghdl_make.log')
    if ($LASTEXITCODE -ne 0) {
      Get-Content (Join-Path $dir 'ghdl_make.log') -Tail 60
      throw 'W01_NEO_GHDL_MAKE_FAIL'
    }
    $out = Join-Path $rtl 'w01_neo_top.v'
    & ghdl synth --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" "-P$lib" --out=verilog w01_neo_top 1> $out 2> (Join-Path $dir 'ghdl_synth.log')
    if ($LASTEXITCODE -ne 0) {
      Get-Content (Join-Path $dir 'ghdl_synth.log') -Tail 70
      throw 'W01_NEO_GHDL_SYNTH_FAIL'
    }
    if ((Get-Item -LiteralPath $out).Length -lt 1000) { throw 'W01_NEO_CONVERTED_RTL_TOO_SMALL' }
    $tcl = @'
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/w01_nano9k.cst
add_file constraints/w01_nano9k.sdc
add_file rtl/w01_neo_top.v
set_option -top_module w01_neo_top
set_option -output_base_name w01_neo_nano9k
set_option -synthesis_tool gowinsynthesis
run all
'@
  }
  $tcl | Set-Content -LiteralPath (Join-Path $work 'gowin_fit.tcl') -Encoding utf8
  # All PnR sources, constraints, ROM, and generated RTL are hash-listed.
  $inputs = @(
    Get-ChildItem -LiteralPath $work -Recurse -File |
      Sort-Object FullName |
      ForEach-Object {
        [pscustomobject]@{
          File = $_.FullName.Substring($work.Length+1).Replace('\','/')
          SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
      }
  )
  $inputs | Export-Csv -LiteralPath (Join-Path $dir 'input_sha256.csv') -NoTypeInformation -Encoding utf8
  $log = Join-Path $dir 'gowin.log'
  Push-Location $work
  try {
    & $gowin 'gowin_fit.tcl' *> $log
    $rc = $LASTEXITCODE
  } finally { Pop-Location }
  if ($rc -ne 0) {
    Get-Content -LiteralPath $log -Tail 100
    throw ('W01_' + $cpu + '_PNR_FAIL')
  }
  $found = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter ($top+'.fs'))
  if ($found.Count -ne 1) { throw ('W01_' + $cpu + '_BITSTREAM_COUNT_FAIL') }
  $fs = Join-Path $dir ($top+'.fs')
  Copy-Item -LiteralPath $found[0].FullName -Destination $fs
  $sha = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
  $audit = Join-Path $dir 'pnr_audit.json'
  & python (Join-Path $w01 'tools\audit_w01_pnr.py') --work $work --top $top --sdc (Join-Path $con 'w01_nano9k.sdc') --gowin-log $log --fs $fs --expected-sha $sha --json $audit
  if ($LASTEXITCODE -ne 0) {
    throw ('W01_' + $cpu + '_PREBOARD_AUDIT_FAIL: DO NOT PROGRAM')
  }
  $results[$cpu] = [ordered]@{ FS=$fs; SHA256=$sha; Audit=$audit }
  Write-Host ('W01_' + $cpu + '_FIT_SCREEN_PASS: SHA256=' + $sha) -ForegroundColor Green
}
$receipt = [ordered]@{
  Stage='W01_FIT'
  DateUtc=(Get-Date).ToUniversalTime().ToString('o')
  SimJob=$sim
  SimReceiptSHA256=(Get-FileHash -LiteralPath $simReceiptPath -Algorithm SHA256).Hash
  Status='BOTH_FIT_SCREEN_PASS'
  Pico=$results['pico']
  Neo=$results['neo']
  Board='NOT_RUN'
  Flash='NOT_TOUCHED'
  SD='NOT_TOUCHED'
}
$receipt | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath (Join-Path $job 'receipt.json') -Encoding utf8
Write-Host "W01_BOTH_FIT_SCREEN_PASS: $job" -ForegroundColor Green
Write-Host 'W01_BOARD_NOT_RUN: no SRAM, Flash, SD, or programmer access.'
