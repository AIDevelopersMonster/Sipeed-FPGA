#requires -Version 7.0
<#
LAB-07 phase A: reproducible, pinned Apache-2.0 PSRAM demo source.
Default: preflight only; -Build opts into Gowin synthesis/PnR.
No JTAG, FPGA programming, configuration Flash, microSD, CPU or games.
The vendor-generated Gowin PLL reference file stays in ignored _deps/_build.
EXPERIMENTAL: built .fs is never authorized for programming by this script.
#>
[CmdletBinding()]
param(
    [switch]$Build,
    [switch]$LeanUart,
    [string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$PSNativeCommandUseErrorActionPreference=$false
if($LeanUart -and -not $Build){throw 'LAB07_LEAN_UART_REQUIRES_BUILD'}

if(-not (Get-Command git -ErrorAction SilentlyContinue)) {throw 'LAB07_GIT_MISSING'}
$repo = ([string](& git -C $PSScriptRoot rev-parse --show-toplevel)).Trim()
if($LASTEXITCODE -ne 0 -or -not(Test-Path (Join-Path $repo 'sources.lock.json'))) {
    throw 'LAB07_NOT_IN_SIPEED_FPGA_REPOSITORY'
}
$lab = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$dep = Join-Path $lab '_deps\zf3-psram-tang-nano-9k'
$pin = '394ae14a68f112729f79f78cbfc62a95d874d632'
$url = 'https://github.com/zf3/psram-tang-nano-9k.git'
if(-not(Test-Path -LiteralPath $dep -PathType Container)) {
    New-Item -ItemType Directory -Force (Split-Path $dep -Parent) | Out-Null
    Write-Host 'LAB07_CLONE_PINNED_REFERENCE: local ignored source, Apache-2.0'
    & git clone -q $url $dep
    if($LASTEXITCODE -ne 0){throw 'LAB07_REFERENCE_CLONE_FAIL'}
}
$dirty = @(& git -C $dep status --porcelain --untracked-files=no)
if($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
    throw 'LAB07_REFERENCE_DIRTY: do not overwrite changes in _deps'
}
$at = ([string](& git -C $dep rev-parse HEAD)).Trim()
if($at -cne $pin) {
    & git -C $dep checkout --detach -q $pin
    if($LASTEXITCODE -ne 0){throw 'LAB07_REFERENCE_PIN_NOT_LOCAL: fetch pinned commit only'}
}
$at = ([string](& git -C $dep rev-parse HEAD)).Trim()
if($at -cne $pin){throw 'LAB07_REFERENCE_SHA_MISMATCH'}
if(-not((Get-Content (Join-Path $dep 'LICENSE.txt') -Raw) -match 'Apache License')){
    throw 'LAB07_LICENSE_NOT_VERIFIED'
}
$files = @(
    'src/psram_controller.v',
    'src/psram_test_top.v',
    'src/gowin_rpll/gowin_rpll.v',
    'src/uart_tx.v',
    'src/print.v'
)
foreach($relative in $files) {
    $full = Join-Path $dep ($relative.Replace('/','\'))
    if(-not(Test-Path $full -PathType Leaf)) {throw "LAB07_REFERENCE_MISSING: $relative"}
}
$controller = Get-Content (Join-Path $dep 'src\psram_controller.v') -Raw
$test = Get-Content (Join-Path $dep 'src\psram_test_top.v') -Raw
$pll = Get-Content (Join-Path $dep 'src\gowin_rpll\gowin_rpll.v') -Raw
if(-not $controller.Contains('module PsramController') -or
   -not $controller.Contains('We currently only use the first die (4MB)') -or
   -not $test.Contains('localparam [21:0] BYTES = 1024*1024;') -or
   -not $test.Contains('All done successfully.') -or
   -not $pll.Contains('FBDIV_SEL = 2;')) {
    throw 'LAB07_UPSTREAM_INTERFACE_CHANGED: do not infer safe hardware'
}
Write-Host "LAB07_REFERENCE_PIN_PASS: $pin" -ForegroundColor Green
Write-Host 'LAB07_MEMORY_SCOPE: 64Mbit total PSRAM; demo addresses only FIRST DIE, FIRST 1MiB'
Write-Host 'LAB07_CLOCK_PLAN: 27MHz input -> 81MHz PLL + 90-degree phase; DDR paths require dedicated STA review.'
Write-Host 'LAB07_RESET_PLAN: verified S1 pin3 (1.8V), NOT original upstream pin4.'
Write-Host 'LAB07_UPSTREAM_LICENCE: Apache-2.0; Gowin generated PLL is vendor material, never committed.'
# Cheap safety preflight: no build if actual board IO locations were edited.
$cst = Get-Content -LiteralPath (Join-Path $lab 'constraints\psram07_nano9k.cst') -Raw
$requiredPins = @(
  'IO_LOC "sys_clk" 52;',
  'IO_LOC "sys_resetn" 3;',
  'IO_LOC "uart_txp" 17;',
  'IO_PORT "sys_clk" IO_TYPE=LVCMOS33 PULL_MODE=NONE BANK_VCCIO=3.3;',
  'IO_PORT "sys_resetn" IO_TYPE=LVCMOS18 PULL_MODE=UP;'
)
foreach($requiredPin in $requiredPins) {
    if(-not $cst.Contains($requiredPin)) {
        throw "LAB07_PIN_PREFLIGHT_BLOCKED: $requiredPin"
    }
}
Write-Host 'LAB07_BOARD_PIN_PREFLIGHT_PASS: clock52, reset3, UART17; voltage constraints pinned.'
if(-not $Build) {
    Write-Host 'LAB07_PREFLIGHT_PASS_NO_FPGA_ACTION: use -Build for isolated Gowin candidate.'
    return
}
$gowin = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not(Test-Path $gowin -PathType Leaf)){throw "LAB07_GOWIN_CLI_MISSING: $gowin"}
$job = Join-Path $lab ('_build\fit_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
$work = Join-Path $job 'work'
$rtl = Join-Path $work 'rtl'
$con = Join-Path $work 'constraints'
New-Item -ItemType Directory -Force -Path $rtl,$con | Out-Null
Copy-Item (Join-Path $dep 'src\psram_controller.v') (Join-Path $rtl 'psram_controller.v')
Copy-Item (Join-Path $dep 'src\gowin_rpll\gowin_rpll.v') (Join-Path $rtl 'gowin_rpll.v')
Copy-Item (Join-Path $dep 'src\uart_tx.v') (Join-Path $rtl 'uart_tx.v')
if($LeanUart) {
    Copy-Item (Join-Path $lab 'rtl\lab07_uart_result.v') (Join-Path $rtl 'lab07_uart_result.v')
} else {
    Copy-Item (Join-Path $dep 'src\print.v') (Join-Path $rtl 'print.v')
}

# Only 2 audited board-specific changes to reference test top:
# 1) remove unused button port to avoid driving/claiming JTAG pin 4;
# 2) fix original 22-bit-to-6-bit truncation hiding the error indicator.
$testSrc = Get-Content (Join-Path $dep 'src\psram_test_top.v') -Raw
$oldButton = '    input button,   // 0 when pressed'
$oldLed = 'assign led = ~{error, dout_parity, dout, state};'
if([regex]::Matches($testSrc, [regex]::Escape($oldButton)).Count -ne 1 -or
   [regex]::Matches($testSrc, [regex]::Escape($oldLed)).Count -ne 1) {
    throw 'LAB07_REFERENCE_PATCH_UNSAFE: source fingerprint unexpected'
}
$testSrc = $testSrc.Replace($oldButton, '    // LAB07: unused button removed; sys_resetn maps to physical S1, pin3.')
$testSrc = $testSrc.Replace($oldLed, "assign led = ~{error, 1'b0, state}; // exactly 6 bits; led[5] = FAIL")
if($LeanUart) {
    $start = $testSrc.IndexOf('//Print Controll',[System.StringComparison]::Ordinal)
    $end = $testSrc.LastIndexOf('endmodule',[System.StringComparison]::Ordinal)
    if($start -lt 0 -or $end -le $start) {
        throw 'LAB07_LEAN_UART_PATCH_SOURCE_MISMATCH'
    }
    $light = @'
lab07_uart_result #(.CLOCK_HZ(FREQ),.BAUD(115200)) result_uart (
    .clk(clk), .resetn(sys_resetn), .test_state(state), .uart_tx(uart_txp)
);

'@
    $testSrc = $testSrc.Substring(0,$start) + $light + $testSrc.Substring($end)
    if(-not $testSrc.Contains('    .LATENCY(LATENCY)') -or
       -not $testSrc.Contains('defparam mem_clk_freq=FREQ;')) {
        throw 'LAB07_LEAN_UART_FREQUENCY_PATCH_MISMATCH'
    }
    $testSrc = $testSrc.Replace('    .LATENCY(LATENCY)',
        ('    .FREQ(FREQ),' + [char]10 + '    .LATENCY(LATENCY)'))
    $testSrc = $testSrc.Replace('defparam mem_clk_freq=FREQ;',
        '// LAB07: explicit FREQ=81MHz, identical to original default.')
    $parity='assign dout_parity = dout[7] & dout[6] & dout[5] & dout[4] & dout[3] & dout[2] & dout[1] & dout[0];'
    if(-not $testSrc.Contains($parity)){throw 'LAB07_LEAN_UART_PARITY_PATCH_MISMATCH'}
    $testSrc=$testSrc.Replace($parity, '// unused parity of old diagnostic printer removed')
}
$testSrc | Set-Content -LiteralPath (Join-Path $rtl 'psram_test_top.v') -Encoding utf8
Copy-Item (Join-Path $lab 'constraints\psram07_nano9k.cst') (Join-Path $con 'psram07_nano9k.cst')
Copy-Item (Join-Path $lab 'constraints\psram07_nano9k.sdc') (Join-Path $con 'psram07_nano9k.sdc')
$tcl = @'
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/psram07_nano9k.cst
add_file constraints/psram07_nano9k.sdc
add_file rtl/gowin_rpll.v
add_file rtl/psram_controller.v
add_file rtl/uart_tx.v
add_file rtl/psram_test_top.v
set_option -top_module memory_test
set_option -output_base_name psram07_nano9k
set_option -synthesis_tool gowinsynthesis
run all
'@
if($LeanUart) {
    $tcl = $tcl.Replace('add_file rtl/psram_test_top.v',
        ('add_file rtl/psram_test_top.v' + [char]10 + 'add_file rtl/lab07_uart_result.v'))
    if(-not(Get-Command iverilog -ErrorAction SilentlyContinue) -or
       -not(Get-Command vvp -ErrorAction SilentlyContinue)) {
        throw 'LAB07_UART_SIM_TOOLS_MISSING: iverilog and vvp required in PATH'
    }
    $simDir=Join-Path $job 'uart_sim'
    New-Item -ItemType Directory -Force -Path $simDir | Out-Null
    $simExe=Join-Path $simDir 'tb_lab07_uart_result.vvp'
    $simLog=Join-Path $simDir 'uart_sim.log'
    & iverilog -g2012 -s tb_lab07_uart_result -o $simExe (Join-Path $rtl 'lab07_uart_result.v') (Join-Path $lab 'tests\tb_lab07_uart_result.v') *> $simLog
    if($LASTEXITCODE -ne 0) {
        Get-Content -LiteralPath $simLog -Tail 45
        throw 'LAB07_UART_SIM_COMPILE_FAIL'
    }
    & vvp $simExe *>> $simLog
    if($LASTEXITCODE -ne 0 -or
       -not((Get-Content -LiteralPath $simLog -Raw).Contains('LAB07_UART_TB_PASS'))) {
        Get-Content -LiteralPath $simLog -Tail 45
        throw 'LAB07_UART_SIM_FAIL'
    }
    Write-Host 'LAB07_UART_TB_PASS: exact PASS/FAIL frames verified.' -ForegroundColor Green
}
$tcl | Set-Content -LiteralPath (Join-Path $work 'fit.tcl') -Encoding ascii
$manifest = @(
    Get-ChildItem -LiteralPath $work -Recurse -File |
      Sort-Object FullName |
      ForEach-Object {
        [pscustomobject]@{
            RelativePath=$_.FullName.Substring($work.Length+1).Replace('\','/')
            SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
      }
)
$manifest | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Write-Host "LAB07_GOWIN_FIT_JOB: $job"
Write-Host 'LAB07_NO_FPGA_ACTION: synthesis/PnR only; vendor PSRAM memory model NOT cycle-simulated here'
$log = Join-Path $job 'gowin.log'
Push-Location $work
try {
    & $gowin 'fit.tcl' *> $log
    $rc=$LASTEXITCODE
} finally {Pop-Location}
if($rc -ne 0) {
    Write-Host "LAB07_GOWIN_LOG: $log"
    Get-Content -LiteralPath $log -Tail 55
    throw "LAB07_GOWIN_FIT_FAIL: exit=$rc, STOP BEFORE BOARD"
}
$bitstreams = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'psram07_nano9k.fs')
if($bitstreams.Count -ne 1){throw "LAB07_BITSTREAM_COUNT_FAIL: $($bitstreams.Count)"}
$fs=Join-Path $job 'psram07_nano9k.fs'
Copy-Item -LiteralPath $bitstreams[0].FullName -Destination $fs
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
$receipt=[ordered]@{
    Stage='LAB07_PSRAM_FIT_CANDIDATE'
    Status='PNR_COMPLETED_STA_AND_PSRAM_IO_NOT_YET_AUDITED'
    DateUtc=(Get-Date).ToUniversalTime().ToString('o')
    Upstream=$url
    UpstreamCommit=$pin
    PlannedFirstDieSweepBytes=1048576
    PhysicallyVerifiedExternalMemoryBytes=0
    Bitstream=$fs
    BitstreamSHA256=$sha
    InputsManifest=(Join-Path $job 'input_sha256.csv')
    GowinLog=$log
    Hardware='NOT_RUN'
    Flash='NOT_TOUCHED'
    SD='NOT_TOUCHED'
}
if($LeanUart){
    $receipt['DiagnosticMode']='LEAN_TERMINAL_UART'
    $receipt['UartSim']='PASS'
}
$receipt | ConvertTo-Json -Depth 5 |
  Set-Content -LiteralPath (Join-Path $job 'receipt.json') -Encoding utf8
Write-Host "LAB07_PNR_CANDIDATE_SHA: $sha" -ForegroundColor Green
Write-Host "LAB07_GOWIN_LOG: $log"
Write-Host "LAB07_FIT_RECEIPT: $(Join-Path $job 'receipt.json')"
Write-Host 'LAB07_HARDWARE_BLOCKED: review PSRAM port binding, 81MHz clock/DDR STA, pins, and reset before SRAM-only programming.' -ForegroundColor Yellow
