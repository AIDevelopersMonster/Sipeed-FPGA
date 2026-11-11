#requires -Version 7.0
<#
  LAB-06.1B: real pinned NEORV32 RV32I firmware + GHDL execution.
  Zero FPGA, JTAG, SD or Flash access. Isolated _build job, no vendor edits.
  Usage after activate_ucrt64.ps1:
    .\02-NEORV32\tools\run_lab061.ps1 -Mode Firmware
    .\02-NEORV32\tools\run_lab061.ps1 -Mode Sim
#>
[CmdletBinding()]
param([ValidateSet('Firmware','Sim')][string]$Mode = 'Sim')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$lab = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$root = (Resolve-Path (Join-Path $lab '..')).Path
$upstream = Join-Path $lab '_deps\neorv32'
$pinned = 'b2620454ebb2407e81a6a1965ef52e2a860b0432'
if (-not (Test-Path -LiteralPath (Join-Path $upstream 'rtl\file_list_core.f'))) {
    throw 'Pinned NEORV32 sources missing. Run preflight.ps1 -FetchUpstream first.'
}
$actual = (& git -C $upstream rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or [string]$actual.Trim().ToLowerInvariant() -cne $pinned) {
    throw 'Pinned NEORV32 source commit mismatch; refuse to build.'
}

$needed = @('riscv64-unknown-elf-gcc','riscv64-unknown-elf-objcopy','gcc')
if ($Mode -eq 'Sim') { $needed += 'ghdl' }
foreach ($name in $needed) {
    if (-not (Get-Command -Name $name -ErrorAction SilentlyContinue)) {
        throw "Missing tool in PATH: $name. Run activate_ucrt64.ps1 first."
    }
}

$job = Join-Path $lab ('_build\run_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$firmwareDir = Join-Path $lab 'firmware'
$elf = Join-Path $job 'lab061.elf'
$binary = Join-Path $job 'lab061.bin'
$image = Join-Path $job 'neorv32_imem_image.vhd'
$gen = Join-Path $job 'image_gen.exe'
$map = Join-Path $job 'lab061.map'
$buildLog = Join-Path $job 'build.log'
New-Item -ItemType Directory -Force -Path $job | Out-Null

Write-Host "LAB061_PINNED_SOURCE: $pinned"
Write-Host "LAB061_JOB: $job"
$gccArgs = @(
    '-march=rv32i', '-mabi=ilp32', '-Os',
    '-ffreestanding', '-fno-builtin', '-fno-pic', '-fdata-sections',
    '-ffunction-sections', '-msmall-data-limit=0',
    '-nostdlib', '-nostartfiles', '-Wl,--gc-sections',
    "-Wl,-Map,$map", '-T', (Join-Path $firmwareDir 'linker.ld'),
    (Join-Path $firmwareDir 'lab061.S'),
    (Join-Path $firmwareDir 'main.c'), '-o', $elf
)
& riscv64-unknown-elf-gcc @gccArgs *> $buildLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $buildLog -Tail 80
    throw "LAB061_FIRMWARE_GCC_FAIL: exit=$LASTEXITCODE; log=$buildLog"
}

& riscv64-unknown-elf-objcopy -O binary $elf $binary *>> $buildLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $buildLog -Tail 80
    throw 'LAB061_OBJCOPY_FAIL'
}
$nbytes = (Get-Item -LiteralPath $binary).Length
if ($nbytes -lt 16 -or $nbytes -gt 16384 -or $nbytes % 4 -ne 0) {
    throw "LAB061_ROM_SIZE_FAIL: $nbytes; expected 16..16384 bytes, word-aligned"
}

& gcc -O2 -Wall -Wextra (Join-Path $upstream 'sw\image_gen\image_gen.c') -o $gen *>> $buildLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $buildLog -Tail 80
    throw 'LAB061_HOST_IMAGE_GEN_COMPILE_FAIL'
}
& $gen -t vhd -i $binary -o $image *>> $buildLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $buildLog -Tail 80
    throw 'LAB061_IMEM_IMAGE_GEN_FAIL'
}

$imageHash = (Get-FileHash -LiteralPath $image -Algorithm SHA256).Hash
$binaryHash = (Get-FileHash -LiteralPath $binary -Algorithm SHA256).Hash
$inputPaths = @(
  (Join-Path $firmwareDir 'lab061.S'),
  (Join-Path $firmwareDir 'main.c'),
  (Join-Path $firmwareDir 'linker.ld'),
  (Join-Path $lab 'rtl\lab061_neorv32_top.vhd'),
  (Join-Path $lab 'tests\tb_lab061_neorv32.vhd')
)
$inputs = @($inputPaths | ForEach-Object {
  [ordered]@{ Path = $_; SHA256 = (Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash }
})
$receipt = [ordered]@{
  Stage = 'LAB061'
  BuildUtc = (Get-Date).ToUniversalTime().ToString('o')
  SourceCommit = $pinned
  Mode = $Mode
  FirmwareBytes = $nbytes
  FirmwareSHA256 = $binaryHash
  ImemImageSHA256 = $imageHash
  Inputs = $inputs
  Simulation = 'NOT_RUN'
  FitSta = 'NOT_RUN'
  Board = 'NOT_RUN'
}
Write-Host "LAB061_FIRMWARE_IMAGE_BUILT: $nbytes bytes; SHA256=$binaryHash" -ForegroundColor Green
Write-Host "LAB061_IMEM_IMAGE_SHA256: $imageHash"
Write-Host "LAB061_IMEM_IMAGE_PATH: $image"

if ($Mode -eq 'Sim') {
    $libDir = Join-Path $job 'ghdl'
    New-Item -ItemType Directory -Force -Path $libDir | Out-Null
    $list = Join-Path $upstream 'rtl\file_list_core.f'
    $sourceList = [System.Collections.Generic.List[string]]::new()
    $imageCount = 0
    foreach ($line in (Get-Content -LiteralPath $list)) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $prefix = '$NEORV32_HOME/'
        if (-not $line.StartsWith($prefix, [StringComparison]::Ordinal)) {
            throw "Unexpected upstream source-list entry: $line"
        }
        $rel = $line.Substring($prefix.Length)
        if ($rel -eq 'rtl/core/neorv32_imem_image.vhd') {
            $file = $image
            $imageCount++
        } else {
            $file = Join-Path $upstream ($rel.Replace('/', '\'))
        }
        if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
            throw "Missing required VHDL source: $file"
        }
        $sourceList.Add($file)
    }
    if ($imageCount -ne 1 -or $sourceList.Count -lt 35) {
        throw "Invalid VHDL manifest: count=$($sourceList.Count), image occurrences=$imageCount"
    }
    $sourceList.Add((Join-Path $lab 'rtl\lab061_neorv32_top.vhd'))
    $sourceList.Add((Join-Path $lab 'tests\tb_lab061_neorv32.vhd'))
    $importLog = Join-Path $job 'ghdl_import.log'
    $makeLog = Join-Path $job 'ghdl_make.log'
    $simLog = Join-Path $job 'ghdl_sim.log'
    $importArgs = @('-i','--std=08','--ieee=standard','--work=neorv32',"--workdir=$libDir") + $sourceList.ToArray()
    & ghdl @importArgs *> $importLog
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $importLog -Tail 80
        throw "LAB061_GHDL_IMPORT_FAIL: $importLog"
    }
    & ghdl -m --std=08 --ieee=standard --work=neorv32 "--workdir=$libDir" tb_lab061_neorv32 *> $makeLog
    if ($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $makeLog -Tail 120
        throw "LAB061_GHDL_ELAB_FAIL: $makeLog"
    }
    Write-Host 'LAB061_GHDL_ELAB_OK: running live UART bit-level + GPIO test'
    & ghdl -r --std=08 --ieee=standard --work=neorv32 "--workdir=$libDir" tb_lab061_neorv32 --assert-level=error --stop-time=5ms *> $simLog
    $simCode = $LASTEXITCODE
    Get-Content -LiteralPath $simLog -Tail 45
    if ($simCode -ne 0) {
        throw "LAB061_GHDL_SIM_FAIL: exit=$simCode; log=$simLog"
    }
    if (-not (Select-String -LiteralPath $simLog -SimpleMatch 'LAB061_NEORV32_UART_GPIO_TB_PASS' -Quiet)) {
        throw "LAB061_GHDL_NO_TEST_PASS_MARKER: $simLog"
    }
    $receipt.Simulation = 'PASS'
    Write-Host "LAB061_SIM_PASS: pinned real NEORV32 CPU executed RV32I binary; UART bytes and GPIO patterns matched" -ForegroundColor Green
} else {
    Write-Host 'LAB061_FIRMWARE_ONLY: GHDL simulation NOT_RUN'
}
$jsonPath = Join-Path $job 'receipt.json'
$receipt | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding utf8
Write-Host "LAB061_RECEIPT: $jsonPath"
Write-Host 'LAB061_NO_BOARD_ACTION: no Gowin build, FPGA programming, Flash or SD access.'
