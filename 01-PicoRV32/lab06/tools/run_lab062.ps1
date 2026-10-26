#requires -Version 7
<#
LAB06.2A -- real pinned PicoRV32, RV32I compiled ROM, Icarus UART/GPIO test.
No FPGA access, Gowin, Flash or SD.
#>
[CmdletBinding()]
param([ValidateSet('Sim','Firmware')][string] $Mode='Sim')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false

$lab=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$pico=(Resolve-Path (Join-Path $lab '..')).Path
$vendor=Join-Path $pico 'vendor\picorv32'
$pin='ef203c2b0a3fb793280f5114941416c425c5b461'
$cpu=Join-Path $vendor 'picorv32.v'
if(-not (Test-Path -LiteralPath $cpu)){
    throw 'Missing pinned PicoRV32; first run .\01-PicoRV32\tools\fetch_picorv32.ps1'
}
$rev=(& git -C $vendor rev-parse HEAD)
if($LASTEXITCODE -ne 0 -or ([string]$rev).Trim() -cne $pin){
    throw "LAB062_CPU_PIN_FAIL: $rev"
}
$dirty=@(& git -C $vendor status --porcelain --untracked-files=no)
if($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0){throw 'Pinned PicoRV32 tracked sources modified'}
$tools=@('riscv64-unknown-elf-gcc','riscv64-unknown-elf-objcopy','python')
if($Mode -eq 'Sim'){$tools+=@('iverilog','vvp')}
foreach($tool in $tools){
    if(-not (Get-Command $tool -ErrorAction SilentlyContinue)){
        throw "Tool missing: $tool; run .\02-NEORV32\tools\activate_ucrt64.ps1"
    }
}
$job=Join-Path $lab ('_build\run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
New-Item -Path $job -ItemType Directory -Force | Out-Null
$fw=Join-Path $lab 'firmware'
$elf=Join-Path $job 'lab062.elf'
$bin=Join-Path $job 'lab062.bin'
$hex=Join-Path $job 'lab062_boot.hex'
$log=Join-Path $job 'gcc.log'
Write-Host "LAB062_SOURCE_PIN_PASS: $pin"
Write-Host "LAB062_JOB: $job"

& riscv64-unknown-elf-gcc -march=rv32i -mabi=ilp32 -Os -ffreestanding -fno-builtin -fno-pic -fdata-sections -ffunction-sections -msmall-data-limit=0 -nostdlib -nostartfiles '-Wl,--gc-sections' -T (Join-Path $fw 'linker.ld') (Join-Path $fw 'boot.S') (Join-Path $fw 'main.c') -o $elf *> $log
if($LASTEXITCODE -ne 0){
    Get-Content $log -Tail 80
    throw 'LAB062_GCC_FAIL'
}
& riscv64-unknown-elf-objcopy -O binary $elf $bin *>> $log
if($LASTEXITCODE -ne 0){throw 'LAB062_OBJCOPY_FAIL'}
& python (Join-Path $lab 'tools\make_rom.py') $bin $hex *>> $log
if($LASTEXITCODE -ne 0){
    Get-Content $log -Tail 80
    throw 'LAB062_MAKE_ROM_FAIL'
}
if(@(Get-Content $hex).Count -ne 4096){throw 'LAB062_ROM_LINES_FAIL'}
$size=(Get-Item $bin).Length
$bsha=(Get-FileHash $bin -Algorithm SHA256).Hash
$hsha=(Get-FileHash $hex -Algorithm SHA256).Hash
Write-Host "LAB062_FW_IMAGE_PASS: $size bytes SHA256=$bsha"
Write-Host "LAB062_ROM_IMAGE_PASS: 16384 bytes SHA256=$hsha"

$originals=@(
    $cpu,
    (Join-Path $pico 'rtl\uart_tx_8n1.v'),
    (Join-Path $pico 'rtl\uart_rx_8n1.v'),
    (Join-Path $lab 'rtl\lab062_pico_soc.v'),
    (Join-Path $lab 'tests\tb_lab062_pico.v'),
    (Join-Path $fw 'boot.S'),(Join-Path $fw 'main.c'),
    (Join-Path $fw 'linker.ld'),(Join-Path $lab 'tools\make_rom.py')
)
$inputs=@($originals | ForEach-Object {
    [ordered]@{Path=$_;SHA256=(Get-FileHash $_ -Algorithm SHA256).Hash}
})
$sim='NOT_RUN'
if($Mode -eq 'Sim'){
    $rtl=@($originals[0..4] | ForEach-Object {
        $dest=Join-Path $job (Split-Path $_ -Leaf)
        Copy-Item -LiteralPath $_ -Destination $dest
        $dest
    })
    $vvp=Join-Path $job 'lab062.vvp'
    $compile=Join-Path $job 'iverilog.log'
    $runlog=Join-Path $job 'vvp.log'
    & iverilog -g2012 -s tb_lab062_pico -o $vvp @rtl *> $compile
    if($LASTEXITCODE -ne 0){
        Get-Content $compile -Tail 70
        throw 'LAB062_IVERILOG_FAIL'
    }
    Push-Location $job
    try {
        & vvp $vvp *> $runlog
        $rc=$LASTEXITCODE
    } finally {Pop-Location}
    Get-Content $runlog -Tail 30
    if($rc -ne 0 -or -not (Select-String -LiteralPath $runlog -SimpleMatch 'LAB062_PICORV32_UART_GPIO_TB_PASS' -Quiet)){
        throw "LAB062_SIM_FAIL: $runlog"
    }
    $sim='PASS'
    Write-Host "LAB062_SIM_PASS: real PicoRV32 CPU, UART 16 bytes + GPIO patterns" -ForegroundColor Green
}
$receipt=[ordered]@{
    Stage='LAB062_A'; UpstreamCommit=$pin
    DateUtc=(Get-Date).ToUniversalTime().ToString('o')
    FirmwareBytes=$size; FirmwareSHA256=$bsha
    ROMBytes=16384; RAMBytes=2048; ROMSHA256=$hsha
    Isa='rv32i'; ClockHz=27000000; UART='115200_8N1'
    Simulation=$sim; Gowin='NOT_RUN'; Board='NOT_RUN'; Inputs=$inputs
}
$rpath=Join-Path $job 'receipt.json'
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $rpath -Encoding utf8
Write-Host "LAB062_RECEIPT: $rpath"
Write-Host 'LAB062_NO_BOARD_ACTION: no Gowin build, programming, Flash or SD.'
