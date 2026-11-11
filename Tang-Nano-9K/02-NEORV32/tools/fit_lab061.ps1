#requires -Version 7.0
<#
LAB-06.1C: convert an EXACT SIM-PASS NEORV32 VHDL design into Verilog via GHDL,
then run isolated Gowin PnR on Tang Nano 9K. NEVER programs FPGA, Flash or SD.

Example:
  .\02-NEORV32\tools\activate_ucrt64.ps1
  .\02-NEORV32\tools\fit_lab061.ps1 -SimJob 'C:\GitHub\Sipeed-FPGA\02-NEORV32\_build\run_20261026_132020_122'

The candidate .fs is retained only for review. It is NOT hardware-qualified.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SimJob,
    [string] $GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$lab = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$dep = Join-Path $lab '_deps\neorv32'
$pin = 'b2620454ebb2407e81a6a1965ef52e2a860b0432'
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
foreach ($cmd in @('git', 'ghdl', 'python')) {
    if (-not (Get-Command $cmd -ErrorAction SilentlyContinue)) {
        throw "Missing required command: $cmd. Run activate_ucrt64.ps1 first."
    }
}
if (-not (Test-Path -LiteralPath $gw -PathType Leaf)) {
    throw "Gowin CLI missing: $gw"
}
if (-not (Test-Path -LiteralPath (Join-Path $dep 'rtl\file_list_core.f') -PathType Leaf)) {
    throw 'NEORV32 pinned checkout missing; run preflight.ps1'
}
$rev = (& git -C $dep rev-parse HEAD)
if ($LASTEXITCODE -ne 0 -or ([string]$rev).Trim().ToLowerInvariant() -cne $pin) {
    throw "Wrong NEORV32 revision: $rev; expected $pin"
}
$dirty = @(& git -C $dep status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -ne 0) {
    throw 'Tracked files in pinned upstream checkout have changed. Refuse to synthesize.'
}

$sim = (Resolve-Path -LiteralPath $SimJob -ErrorAction Stop).Path
$receiptPath = Join-Path $sim 'receipt.json'
if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) {
    throw "Missing simulation receipt: $receiptPath"
}
$simReceipt = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($simReceipt.SourceCommit -cne $pin -or $simReceipt.Simulation -cne 'PASS') {
    throw 'Simulation receipt lacks exact source pin + SIM PASS'
}
$simLog = Join-Path $sim 'ghdl_sim.log'
if (-not (Test-Path -LiteralPath $simLog) -or
    -not (Select-String -LiteralPath $simLog -SimpleMatch 'LAB061_NEORV32_UART_GPIO_TB_PASS' -Quiet)) {
    throw 'No physical UART/GPIO SIM PASS marker in exact simulation log'
}
$verifiedImage = Join-Path $sim 'neorv32_imem_image.vhd'
$verifiedBinary = Join-Path $sim 'lab061.bin'
foreach ($check in @(
    @{path=$verifiedImage; sha=$simReceipt.ImemImageSHA256; label='IMEM VHDL'},
    @{path=$verifiedBinary; sha=$simReceipt.FirmwareSHA256; label='RV32I binary'}
)) {
    if (-not (Test-Path -LiteralPath $check.path -PathType Leaf)) {
        throw "Missing $($check.label): $($check.path)"
    }
    $sha = (Get-FileHash -LiteralPath $check.path -Algorithm SHA256).Hash
    if ($sha -cne [string]$check.sha) {
        throw "$($check.label) SHA256 mismatch! expected=$($check.sha) actual=$sha"
    }
}
# A previously accepted ROM must correspond to the exact PRESENT source files.
foreach ($item in @($simReceipt.Inputs)) {
    $path = [string]$item.Path
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "SIM source moved or missing: $path"
    }
    $sha = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    if ($sha -cne [string]$item.SHA256) {
        throw "SIM source changed since acceptance: $path"
    }
}

$job = Join-Path $lab ('_build\fit_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff') + '_' +
    [guid]::NewGuid().ToString('N').Substring(0,6))
$work = Join-Path $job 'work'
$coreDir = Join-Path $work 'rtl\core'
$libDir = Join-Path $work 'ghdl_lib'
$constraints = Join-Path $work 'constraints'
New-Item -ItemType Directory -Force -Path $coreDir,$libDir,$constraints | Out-Null
Write-Host "LAB061_FIT_JOB: $job"
Write-Host "LAB061_SIM_EVIDENCE_PASS: $receiptPath"
Write-Host "LAB061_SIM_IMEM_SHA256_PASS: $($simReceipt.ImemImageSHA256)"
Write-Host "LAB061_FPGA_ACTION: NONE (no programmer/flash access)"

# Stage only required RTL, replacing upstream demo ROM with the actual SIM-PASS ROM.
# Copy into isolated workspace; GHDL never compiles from mutable vendor paths.
$sourceList = [System.Collections.Generic.List[string]]::new()
$images = 0
foreach ($entry in (Get-Content -LiteralPath (Join-Path $dep 'rtl\file_list_core.f'))) {
    $line = $entry.Trim()
    if ($line -eq '' -or $line.StartsWith('#')) { continue }
    $prefix = '$NEORV32_HOME/'
    if (-not $line.StartsWith($prefix, [StringComparison]::Ordinal)) {
        throw "Unexpected source list entry: $line"
    }
    $rel = $line.Substring($prefix.Length)
    if (-not $rel.StartsWith('rtl/core/', [StringComparison]::Ordinal) -or $rel.Contains('..')) {
        throw "Unexpected core path: $rel"
    }
    $stage = Join-Path $work ($rel.Replace('/','\'))
    $origin = Join-Path $dep ($rel.Replace('/','\'))
    if ($rel -eq 'rtl/core/neorv32_imem_image.vhd') {
        $origin = $verifiedImage
        $images++
    }
    if (-not (Test-Path -LiteralPath $origin -PathType Leaf)) { throw "Missing VHDL: $origin" }
    Copy-Item -LiteralPath $origin -Destination $stage
    $sourceList.Add($stage)
}
if ($images -ne 1 -or $sourceList.Count -lt 40) {
    throw "Invalid pinned file list or IMEM substitution: files=$($sourceList.Count) rom=$images"
}
$stageTop = Join-Path $work 'rtl\lab061_neorv32_top.vhd'
Copy-Item -LiteralPath (Join-Path $lab 'rtl\lab061_neorv32_top.vhd') -Destination $stageTop
$sourceList.Add($stageTop)
foreach ($c in @('lab061_nano9k.cst','lab061_nano9k.sdc')) {
    Copy-Item -LiteralPath (Join-Path $lab "constraints\$c") -Destination $constraints
}
$allInputs = @(Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName |
    Where-Object { $_.Extension -in @('.vhd','.cst','.sdc') } |
    ForEach-Object {
        [pscustomobject]@{
            Path = $_.FullName.Substring($work.Length + 1).Replace('\','/')
            SHA256 = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
        }
    })
$allInputs | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -Encoding utf8 -NoTypeInformation
$ghdlImportLog = Join-Path $job 'ghdl_import.log'
$ghdlMakeLog = Join-Path $job 'ghdl_make.log'
$ghdlSynthLog = Join-Path $job 'ghdl_synth.log'
$verilog = Join-Path $work 'rtl\lab061_neorv32_top.v'
$importArgs = @('-i','--std=08','--ieee=standard','--work=neorv32',"--workdir=$libDir") + $sourceList.ToArray()
& ghdl @importArgs *> $ghdlImportLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $ghdlImportLog -Tail 60
    throw "LAB061_GHDL_IMPORT_FAIL: $ghdlImportLog"
}
& ghdl -m --std=08 --ieee=standard --work=neorv32 "--workdir=$libDir" lab061_neorv32_top *> $ghdlMakeLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $ghdlMakeLog -Tail 100
    throw "LAB061_GHDL_MAKE_FAIL: $ghdlMakeLog"
}
# Official NEORV32 conversion flow: synth VHDL to single all-Verilog wrapper.
# KEEP stdout (RTL) and stderr (diagnostics) separate.
& ghdl synth --std=08 --ieee=standard --work=neorv32 "--workdir=$libDir" "-P$libDir" --out=verilog lab061_neorv32_top 1> $verilog 2> $ghdlSynthLog
if ($LASTEXITCODE -ne 0) {
    Get-Content -LiteralPath $ghdlSynthLog -Tail 100
    throw "LAB061_GHDL_SYNTH_VERILOG_FAIL: $ghdlSynthLog"
}
if (-not (Test-Path -LiteralPath $verilog -PathType Leaf) -or
    (Get-Item -LiteralPath $verilog).Length -lt 1000 -or
    -not (Select-String -LiteralPath $verilog -Pattern '^\s*module\s+lab061_neorv32_top\b' -Quiet)) {
    throw "LAB061_INVALID_CONVERTED_VERILOG: $verilog"
}
$verilogHash = (Get-FileHash -LiteralPath $verilog -Algorithm SHA256).Hash
Write-Host "LAB061_GHDL_TO_VERILOG_PASS: $verilogHash" -ForegroundColor Green

# Known compatible Gowin CLI form; input and output are isolated.
# No VHDL library mismatch in Gowin: the GHDL-generated Verilog is one design.
$tcl = Join-Path $work 'gowin_fit.tcl'
@'
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/lab061_nano9k.cst
add_file constraints/lab061_nano9k.sdc
add_file rtl/lab061_neorv32_top.v
set_option -top_module lab061_neorv32_top
set_option -output_base_name lab061_neorv32_nano9k
set_option -synthesis_tool gowinsynthesis
run all
'@ | Set-Content -LiteralPath $tcl -Encoding utf8

$gowinLog = Join-Path $job 'gowin_cli.log'
Push-Location $work
try {
    & $gw 'gowin_fit.tcl' *> $gowinLog
    $gowinExit = $LASTEXITCODE
} finally { Pop-Location }
Write-Host "LAB061_GOWIN_LOG: $gowinLog"
if ($gowinExit -ne 0) {
    Get-Content -LiteralPath $gowinLog -Tail 100
    throw "LAB061_GOWIN_PNR_FAIL: exit=$gowinExit"
}
$bitstreams = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'lab061_neorv32_nano9k.fs')
if ($bitstreams.Count -ne 1) {
    Get-Content -LiteralPath $gowinLog -Tail 80
    throw "LAB061_GOWIN_BITSTREAM_MISSING: found $($bitstreams.Count)"
}
$bitstream = Join-Path $job 'lab061_neorv32_nano9k.fs'
Copy-Item -LiteralPath $bitstreams[0].FullName -Destination $bitstream
$bitstreamHash = (Get-FileHash -LiteralPath $bitstream -Algorithm SHA256).Hash
Write-Host "LAB061_PNR_BITSTREAM_CANDIDATE: $bitstream"
Write-Host "LAB061_BITSTREAM_SHA256: $bitstreamHash"

$staReports = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter '*_tr_content.html')
if ($staReports.Count -ne 1) {
    throw "LAB061_STA_REPORT_MISSING: found=$($staReports.Count); inspect $gowinLog. DO NOT PROGRAM"
}
$sta = $staReports[0].FullName
$staAuditLog = Join-Path $job 'sta_audit.log'
& python (Join-Path $lab 'tools\check_sta_lab061.py') $sta --log $gowinLog *> $staAuditLog
$staExit = $LASTEXITCODE
Get-Content -LiteralPath $staAuditLog -Tail 40
$fitReceipt = [ordered]@{
    Stage = 'LAB061_FIT'
    DateUtc = (Get-Date).ToUniversalTime().ToString('o')
    PinnedUpstreamCommit = $pin
    SimJob = $sim
    SimReceiptSHA256 = (Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash
    ImemImageSHA256 = [string]$simReceipt.ImemImageSHA256
    SimStatus = 'PASS'
    Flow = 'GHDL VHDL to Verilog -> Gowin CLI'
    GowinDevice = 'GW1NR-9C GW1NR-LV9QN88PC6/I5'
    ClockHz = 27000000
    ConvertedVerilogSHA256 = $verilogHash
    BitstreamCandidateSHA256 = $bitstreamHash
    TimingHtml = $sta
    StaScreen = if ($staExit -eq 0) { 'PRELIM_PASS' } else { 'FAIL_OR_INCOMPLETE' }
    Board = 'NOT_RUN'
}
$fitReceipt | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $job 'fit_receipt.json') -Encoding utf8
if ($staExit -ne 0) {
    throw "LAB061_STA_SCREEN_FAIL: $staAuditLog; DO NOT PROGRAM"
}
Write-Host "LAB061_FIT_STA_PRELIM_PASS: inspect full clocks, constraints, CDC, and unconstrainted paths before SRAM use" -ForegroundColor Green
Write-Host "LAB061_FIT_REPORT: $sta"
Write-Host 'LAB061_BOARD_NOT_RUN: this script NEVER invokes Gowin Programmer or writes Flash/SD.'
