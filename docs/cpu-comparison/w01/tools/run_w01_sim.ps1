#requires -Version 7
# W01: real PicoRV32 and NEORV32 RTL simulation; NO Gowin/programmer/Flash/SD.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$CompileJob)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$w01=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$repo=(Resolve-Path (Join-Path $w01 '..\..\..')).Path
$compile=(Resolve-Path -LiteralPath $CompileJob).Path
$r=Get-Content (Join-Path $compile 'receipt.json') -Raw|ConvertFrom-Json
if($r.Stage -cne 'W01_COMPILER' -or $r.Status -cne 'COMPILE_PASS_SIM_NOT_RUN' -or $r.WorkloadInstructionWords -lt 30) {
 throw 'W01_COMPILE_RECEIPT_INVALID'
}
foreach($cpu in @('pico','neo')) {
 $item=if($cpu -eq 'pico'){$r.Pico}else{$r.Neo}
 if((Get-FileHash -LiteralPath $item.Bin -Algorithm SHA256).Hash -cne $item.SHA256) {
  throw "W01_COMPILER_BINARY_SHA_FAIL: $cpu"
 }
}
$job=Join-Path $w01 ('_build\sim_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item $job -ItemType Directory -Force | Out-Null
Write-Host "W01_SIM_JOB: $job"
foreach($cmd in @('git','iverilog','vvp','ghdl','gcc','python')) {
 if(-not(Get-Command $cmd -ErrorAction SilentlyContinue)){throw "W01_MISSING_TOOL: $cmd"}
}
$picoVendor=Join-Path $repo '01-PicoRV32\vendor\picorv32'
$neoVendor=Join-Path $repo '02-NEORV32\_deps\neorv32'
if(((& git -C $picoVendor rev-parse HEAD).Trim()) -cne 'ef203c2b0a3fb793280f5114941416c425c5b461') {
 throw 'W01_PICO_PIN_FAIL'
}
if(((& git -C $neoVendor rev-parse HEAD).Trim()) -cne 'b2620454ebb2407e81a6a1965ef52e2a860b0432') {
 throw 'W01_NEO_PIN_FAIL'
}

# Pico ROM: exact compiled binary from compiler receipt.
$picoDir=Join-Path $job 'pico'
New-Item $picoDir -ItemType Directory -Force | Out-Null
$hex=Join-Path $picoDir 'w01_pico_boot.hex'
& python (Join-Path $repo '01-PicoRV32\lab06\tools\make_rom.py') $r.Pico.Bin $hex
if($LASTEXITCODE -ne 0){throw 'W01_PICO_ROM_FAIL'}
$verilog=@(
 (Join-Path $picoVendor 'picorv32.v'),
 (Join-Path $repo '01-PicoRV32\rtl\uart_tx_8n1.v'),
 (Join-Path $repo '01-PicoRV32\rtl\uart_rx_8n1.v'),
 (Join-Path $w01 'rtl\w01_pico_soc.v'),
 (Join-Path $w01 'tests\tb_w01_pico.v')
)
$picoVvp=Join-Path $picoDir 'w01_pico.vvp'
& iverilog -g2012 -s tb_w01_pico -o $picoVvp @verilog *> (Join-Path $picoDir 'compile.log')
if($LASTEXITCODE -ne 0) {
 Get-Content (Join-Path $picoDir 'compile.log') -Tail 70
 throw 'W01_PICO_IVERILOG_FAIL'
}
Push-Location $picoDir
try {
 & vvp $picoVvp *> (Join-Path $picoDir 'sim.log')
 $rc=$LASTEXITCODE
} finally {Pop-Location}
Get-Content (Join-Path $picoDir 'sim.log') -Tail 24
if($rc -ne 0 -or -not(Select-String -LiteralPath (Join-Path $picoDir 'sim.log') -SimpleMatch 'W01_PICO_SIM_PASS' -Quiet)) {
 throw 'W01_PICO_SIM_FAIL: stop, no hardware'
}
Write-Host 'W01_PICO_SIM_PASS: actual CPU/digest/UART/cycle counter' -ForegroundColor Green

# NEORV32 image generator and GHDL in independent work dir.
$neoDir=Join-Path $job 'neo'
New-Item $neoDir -ItemType Directory -Force | Out-Null
$gen=Join-Path $neoDir 'image_gen.exe'
$image=Join-Path $neoDir 'neorv32_imem_image.vhd'
& gcc -O2 -Wall -Wextra (Join-Path $neoVendor 'sw\image_gen\image_gen.c') -o $gen *> (Join-Path $neoDir 'imagegen_compile.log')
if($LASTEXITCODE -ne 0){throw 'W01_NEO_IMAGEGEN_GCC_FAIL'}
& $gen -t vhd -i $r.Neo.Bin -o $image *> (Join-Path $neoDir 'imagegen.log')
if($LASTEXITCODE -ne 0){throw 'W01_NEO_IMAGEGEN_FAIL'}
$lib=Join-Path $neoDir 'ghdl'
New-Item $lib -ItemType Directory -Force | Out-Null
$list=[System.Collections.Generic.List[string]]::new()
$images=0
foreach($s in (Get-Content (Join-Path $neoVendor 'rtl\file_list_core.f'))) {
 $s=$s.Trim()
 if(-not $s -or $s.StartsWith('#')){continue}
 if(-not $s.StartsWith('$NEORV32_HOME/')){throw "W01_NEO_LIST_INVALID: $s"}
 $rel=$s.Substring('$NEORV32_HOME/'.Length)
 if($rel -eq 'rtl/core/neorv32_imem_image.vhd'){$list.Add($image);$images++}
 else {$list.Add((Join-Path $neoVendor ($rel.Replace('/','\'))))}
}
if($images -ne 1 -or $list.Count -lt 40){throw 'W01_NEO_MANIFEST_FAIL'}
$list.Add((Join-Path $w01 'rtl\w01_neo_top.vhd'))
$list.Add((Join-Path $w01 'tests\tb_w01_neo.vhd'))
& ghdl -i --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" @($list.ToArray()) *> (Join-Path $neoDir 'import.log')
if($LASTEXITCODE -ne 0){Get-Content (Join-Path $neoDir 'import.log') -Tail 80;throw 'W01_NEO_GHDL_IMPORT_FAIL'}
& ghdl -m --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" tb_w01_neo *> (Join-Path $neoDir 'make.log')
if($LASTEXITCODE -ne 0){Get-Content (Join-Path $neoDir 'make.log') -Tail 80;throw 'W01_NEO_GHDL_MAKE_FAIL'}
& ghdl -r --std=08 --ieee=standard --work=neorv32 "--workdir=$lib" tb_w01_neo --assert-level=error --stop-time=25ms *> (Join-Path $neoDir 'sim.log')
$rc=$LASTEXITCODE
Get-Content (Join-Path $neoDir 'sim.log') -Tail 26
if($rc -ne 0 -or -not(Select-String -LiteralPath (Join-Path $neoDir 'sim.log') -SimpleMatch 'W01_NEO_SIM_PASS' -Quiet)){
 throw 'W01_NEO_SIM_FAIL: stop, no hardware'
}
Write-Host 'W01_NEO_SIM_PASS: actual CPU/digest/UART/cycle counter' -ForegroundColor Green
$receipt=[ordered]@{
 Stage='W01_SIM';Status='BOTH_SIM_PASS'
 CompileJob=$compile
 CompileReceiptSHA256=(Get-FileHash (Join-Path $compile 'receipt.json') -Algorithm SHA256).Hash
 PicoROM=$hex;PicoRomSHA256=(Get-FileHash $hex -Algorithm SHA256).Hash
 NeoIMEM=$image;NeoImemSHA256=(Get-FileHash $image -Algorithm SHA256).Hash
 PicoSimLog=(Join-Path $picoDir 'sim.log')
 NeoSimLog=(Join-Path $neoDir 'sim.log')
 PicoSourcePin='ef203c2b0a3fb793280f5114941416c425c5b461'
 NeoSourcePin='b2620454ebb2407e81a6a1965ef52e2a860b0432'
 Gowin='NOT_RUN';Board='NOT_RUN'
}
$receipt|ConvertTo-Json -Depth 7|Set-Content (Join-Path $job 'receipt.json') -Encoding utf8
Write-Host "W01_BOTH_CPU_SIM_PASS: $job" -ForegroundColor Green
Write-Host 'W01_NO_FPGA_ACTION: no Gowin, SRAM, Flash, SD.'
