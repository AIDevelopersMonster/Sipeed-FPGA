#requires -Version 7.0
<#
LAB-06.1A source and tool preflight for NEORV32 on Tang Nano 9K.
Read-only by default. -FetchUpstream clones the EXACT pinned NEORV32
revision into 02-NEORV32/_deps/neorv32 (gitignored).
No VHDL build, FPGA programming, JTAG, SD or Flash operations.
#>
[CmdletBinding()]
param(
    [switch]$FetchUpstream,
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$labDir = Join-Path $projectRoot '02-NEORV32'
$lockPath = Join-Path $projectRoot 'sources.lock.json'
$lock = Get-Content -LiteralPath $lockPath -Raw -Encoding utf8 | ConvertFrom-Json
$dependencies = @($lock.dependencies | Where-Object { $_.role -eq 'stage02_cpu' })
if ($dependencies.Count -ne 1) { throw 'Missing or duplicate stage02_cpu in sources.lock.json' }
$dep = $dependencies[0]
$pinned = [string]$dep.commit
if ($pinned -cnotmatch '^[0-9a-f]{40}$') { throw 'Invalid pinned git SHA' }
if ([string]$dep.repository -cne 'https://github.com/stnolting/neorv32') {
    throw 'Unexpected stage02 CPU upstream URL'
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is required for a pinned NEORV32 checkout'
}

$checkout = Join-Path $labDir '_deps\neorv32'
if (-not (Test-Path -LiteralPath $checkout -PathType Container)) {
    if (-not $FetchUpstream) {
        throw 'NEORV32 source not checked out. Run with -FetchUpstream once.'
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $checkout) | Out-Null
    Write-Host "LAB06_FETCH: cloning NEORV32 upstream into $checkout"
    & git clone --filter=blob:none --no-checkout 'https://github.com/stnolting/neorv32.git' $checkout
    if ($LASTEXITCODE -ne 0) { throw 'NEORV32 clone failed' }
    & git -C $checkout checkout --detach $pinned
    if ($LASTEXITCODE -ne 0) { throw 'NEORV32 pinned checkout failed' }
}
$head = (& git -C $checkout rev-parse HEAD)
if ($LASTEXITCODE -ne 0) { throw 'NEORV32 checkout is not a valid git worktree' }
$head = ([string]$head).Trim().ToLowerInvariant()
if ($head -cne $pinned) {
    throw "NEORV32 PIN MISMATCH! Expected=$pinned Actual=$head. Existing checkout preserved."
}
$origin = (& git -C $checkout remote get-url origin)
if ($LASTEXITCODE -ne 0 -or [string]$origin -notmatch 'github\.com[:/]stnolting/neorv32(?:\.git)?$') {
    throw "Unexpected upstream origin: $origin"
}

$needed = @(
    'LICENSE',
    'rtl\file_list_core.f',
    'rtl\core\neorv32_top.vhd',
    'rtl\core\neorv32_imem_image.vhd',
    'rtl\test_setups\neorv32_test_setup_approm.vhd',
    'sw\example\hello_world\main.c'
)
foreach ($rel in $needed) {
    $fullPath = Join-Path $checkout $rel
    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        throw "Pinned source missing required file: $rel"
    }
}
$license = Get-Content -LiteralPath (Join-Path $checkout 'LICENSE') -Raw -Encoding utf8
if ($license -notmatch 'BSD 3-Clause License') {
    throw 'Upstream license is not the expected BSD 3-Clause License'
}
$topVhdl = Get-Content -LiteralPath (Join-Path $checkout 'rtl\core\neorv32_top.vhd') -Raw -Encoding utf8
foreach ($key in @('BOOT_MODE_SELECT', 'IMEM_EN', 'IMEM_SIZE', 'DMEM_EN', 'DMEM_SIZE', 'IO_UART0_EN', 'IO_GPIO_NUM')) {
    if (-not $topVhdl.Contains($key)) { throw "Pinned neorv32_top.vhd lacks expected generic: $key" }
}

Write-Host "LAB06_SOURCE_PIN_PASS: $head" -ForegroundColor Green
Write-Host 'LAB06_UPSTREAM_LICENSE_PASS: BSD-3-Clause' -ForegroundColor Green
Write-Host 'LAB06_BOOT_INTERFACE_PASS: BOOT_MODE_SELECT=2, IMEM/DMEM, UART0, GPIO supported as generics' -ForegroundColor Green

$toolnames = @('ghdl','iverilog','vvp','python','riscv-none-elf-gcc','riscv32-unknown-elf-gcc','riscv64-unknown-elf-gcc','make')
$found = [ordered]@{}
foreach ($tool in $toolnames) {
    $cmd = Get-Command -Name $tool -ErrorAction SilentlyContinue
    $found[$tool] = if ($null -eq $cmd) { 'MISSING' } else { [string]$cmd.Source }
    Write-Host ("LAB06_TOOL {0}: {1}" -f $tool, $found[$tool])
}
$gowin = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
$programmer = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
$gowinState = if (Test-Path -LiteralPath $gowin -PathType Leaf) { 'PRESENT' } else { 'MISSING' }
$progState = if (Test-Path -LiteralPath $programmer -PathType Leaf) { 'PRESENT' } else { 'MISSING' }
Write-Host "LAB06_GOWIN_CLI: $gowinState ($gowin)"
Write-Host "LAB06_GOWIN_PROGRAMMER: $progState ($programmer)"

$report = [ordered]@{
    project = 'LAB06-NEORV32'
    stage = '06.1A_SOURCE_PREFLIGHT'
    status = 'SOURCE_PREFLIGHT_PASS'
    verified_at = (Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz')
    source = [ordered]@{
        repository = [string]$dep.repository
        pinned_commit = $pinned
        actual_commit = $head
        checkout = $checkout
        license = 'BSD-3-Clause'
    }
    tools = $found
    gowin_cli = $gowin
    gowin_cli_state = $gowinState
    gowin_programmer_state = $progState
    simulation = 'NOT_RUN'
    gowin_fit_sta = 'NOT_RUN'
    board = 'NOT_RUN'
}
$reportDir = Join-Path $labDir '_reports'
New-Item -ItemType Directory -Force -Path $reportDir | Out-Null
$receipt = Join-Path $reportDir ('LAB06_PREFLIGHT_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.json')
$report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $receipt -Encoding utf8
Write-Host "LAB06_SOURCE_PREFLIGHT_PASS: $receipt" -ForegroundColor Green
if ($found['ghdl'] -eq 'MISSING') {
    Write-Warning 'GHDL missing: VHDL simulation cannot be marked PASS yet.'
}
if ($gowinState -ne 'PRESENT') {
    Write-Warning 'Gowin CLI missing at default path: supply -GowinRoot with the real installation.'
}
if (($found['riscv-none-elf-gcc'] -eq 'MISSING') -and
    ($found['riscv32-unknown-elf-gcc'] -eq 'MISSING') -and
    ($found['riscv64-unknown-elf-gcc'] -eq 'MISSING')) {
    Write-Warning 'No RISC-V GCC found in PATH. Firmware compilation is pending.'
}
Write-Host 'LAB06_NOT_TESTED: no simulation, Gowin build, FPGA/SD/Flash access performed.'
