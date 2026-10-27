#requires -Version 7.0
# W01 compiler gate only; no FPGA or Gowin action.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
$w01=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$common=Join-Path $w01 'common'
foreach($tool in @('python','riscv64-unknown-elf-gcc','riscv64-unknown-elf-objcopy','riscv64-unknown-elf-objdump')) {
 if(-not (Get-Command $tool -ErrorAction SilentlyContinue)){throw "W01_TOOL_MISSING: $tool"}
}
& python (Join-Path $common 'reference_w01.py')
if($LASTEXITCODE -ne 0){throw 'W01_ORACLE_FAIL'}
$job=Join-Path $w01 ('_build\compile_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -Path $job -ItemType Directory -Force | Out-Null
$results=@{}
foreach($cpu in @('pico','neo')) {
 $elf=Join-Path $job "$cpu.elf"
 $bin=Join-Path $job "$cpu.bin"
 $dis=Join-Path $job "$cpu.disasm.txt"
 $log=Join-Path $job "$cpu.gcc.log"
 $params=@('-march=rv32i_zicsr','-mabi=ilp32','-Os','-ffreestanding','-fno-builtin','-fno-pic',
   '-fdata-sections','-ffunction-sections','-msmall-data-limit=0','-nostdlib','-nostartfiles',
   '-Wl,--gc-sections','-T',(Join-Path $common 'linker.ld'),
   (Join-Path $common 'start.S'),(Join-Path $common 'w01_workload.S'),
   (Join-Path $w01 "platform\main_$cpu.c"),'-o',$elf)
 & riscv64-unknown-elf-gcc @params *> $log
 if($LASTEXITCODE -ne 0){Get-Content $log -Tail 60;throw "W01_GCC_FAIL: $cpu"}
 & riscv64-unknown-elf-objcopy -O binary $elf $bin *>> $log
 if($LASTEXITCODE -ne 0){throw "W01_OBJCOPY_FAIL: $cpu"}
 if((Get-Item $bin).Length -gt 16384){throw "W01_IMAGE_TOO_BIG: $cpu"}
 & riscv64-unknown-elf-objdump -d -M no-aliases $elf > $dis
 if($LASTEXITCODE -ne 0){throw "W01_DISASM_FAIL: $cpu"}
 $results[$cpu]=[ordered]@{Bin=$bin;SHA256=(Get-FileHash $bin -Algorithm SHA256).Hash;Disasm=$dis}
 Write-Host "W01_IMAGE_BUILT: $cpu" -ForegroundColor Green
}
function Get-WorkloadWords([string]$path) {
 $s=Get-Content -LiteralPath $path -Raw
 $begin=[regex]::Match($s,'(?m)^\s*[0-9a-f]+\s+<w01_workload>:')
 if(-not $begin.Success){throw 'W01_WORKLOAD_SYMBOL_MISSING'}
 $part=$s.Substring($begin.Index+$begin.Length)
 $next=[regex]::Match($part,'(?m)^\s*[0-9a-f]+\s+<[^>]+>:')
 if($next.Success){$part=$part.Substring(0,$next.Index)}
 $matches=[regex]::Matches($part,'(?m)^\s*[0-9a-f]+:\s+([0-9a-f]{8})\s+')
 $words=@($matches | ForEach-Object {$_.Groups[1].Value})
 if($words.Count -lt 30){throw "W01_TOO_FEW_INSTRUCTIONS: $($words.Count)"}
 return ,$words
}
$a=Get-WorkloadWords $results['pico'].Disasm
$b=Get-WorkloadWords $results['neo'].Disasm
if($a.Count -ne $b.Count -or ($a -join ',') -cne ($b -join ',')){
 throw 'W01_COMMON_MACHINE_CODE_MISMATCH: DO NOT COMPARE CPU SPEED'
}
$receipt=[ordered]@{
 Stage='W01_COMPILER';Status='COMPILE_PASS_SIM_NOT_RUN';ISA='rv32i_zicsr'
 WorkloadInstructionWords=$a.Count
 WorkloadSHA256=(Get-FileHash (Join-Path $common 'w01_workload.S') -Algorithm SHA256).Hash
 Pico=$results['pico'];Neo=$results['neo']
}
$receipt|ConvertTo-Json -Depth 7|Set-Content (Join-Path $job 'receipt.json') -Encoding utf8
Write-Host "W01_COMMON_MACHINE_CODE_PASS: $($a.Count) instruction words" -ForegroundColor Green
Write-Host "W01_COMPILER_RECEIPT: $(Join-Path $job 'receipt.json')"
Write-Host 'W01_SIM_NOT_RUN: no FPGA, Flash, or SD access'
