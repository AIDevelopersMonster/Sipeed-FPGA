#requires -Version 7.0
<#
LAB-06.1C -- read-only pre-board inspection of one completed Gowin FIT job.
No GHDL/Gowin rebuild, FPGA programming, USB/JTAG, Flash, or SD operations.
The existing candidate bitstream is READ, NEVER changed.
Reports internal STA + source/ROM/pin integrity and excerpts resource usage.
External UART timing remains a separate engineering qualification.
Usage:
  .\02-NEORV32\tools\audit_fit_lab061.ps1 -FitJob <fit_job> -ExpectedSHA256 <64-hex>
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string] $FitJob,
  [Parameter(Mandatory = $true)]
  [ValidatePattern('^[0-9A-Fa-f]{64}$')][string] $ExpectedSHA256
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$lab = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$job = (Resolve-Path -LiteralPath $FitJob -ErrorAction Stop).Path
$work = Join-Path $job 'work'
$receiptPath = Join-Path $job 'fit_receipt.json'
$binPath = Join-Path $job 'lab061_neorv32_nano9k.fs'
$reportPath = Join-Path $work 'impl\pnr\lab061_neorv32_nano9k.rpt.txt'
$timingPath = Join-Path $work 'impl\pnr\lab061_neorv32_nano9k_tr_content.html'
$logPath = Join-Path $job 'gowin_cli.log'
$staLogPath = Join-Path $job 'sta_audit.log'
foreach ($p in @($receiptPath,$binPath,$reportPath,$timingPath,$logPath,$staLogPath)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        throw "LAB061_AUDIT_FILE_MISSING: $p"
    }
}
$r = Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($r.Stage -cne 'LAB061_FIT' -or $r.SimStatus -cne 'PASS' -or
    $r.StaScreen -cne 'PRELIM_PASS' -or $r.Board -cne 'NOT_RUN' -or
    $r.PinnedUpstreamCommit -cne 'b2620454ebb2407e81a6a1965ef52e2a860b0432') {
    throw 'LAB061_AUDIT_RECEIPT_INVALID: wrong source, stage or pre-board status'
}
$expected = $ExpectedSHA256.ToUpperInvariant()
$actual = (Get-FileHash -LiteralPath $binPath -Algorithm SHA256).Hash
if ($actual -cne $expected -or $actual -cne [string]$r.BitstreamCandidateSHA256) {
    throw "LAB061_AUDIT_SHA_FAIL: expected=$expected actual=$actual receipt=$($r.BitstreamCandidateSHA256)"
}
Write-Host "LAB061_BITSTREAM_SHA256_PASS: $actual" -ForegroundColor Green

$simPath = Join-Path ([string]$r.SimJob) 'receipt.json'
if (-not (Test-Path -LiteralPath $simPath -PathType Leaf)) {
    throw "LAB061_AUDIT_SIM_RECEIPT_MISSING: $simPath"
}
$sim = Get-Content -LiteralPath $simPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($sim.Simulation -cne 'PASS' -or
    [string]$sim.ImemImageSHA256 -cne [string]$r.ImemImageSHA256) {
    throw 'LAB061_AUDIT_SIM_PROVENANCE_FAIL'
}
$simReceiptSha = (Get-FileHash -LiteralPath $simPath -Algorithm SHA256).Hash
if ($simReceiptSha -cne [string]$r.SimReceiptSHA256) {
    throw 'LAB061_AUDIT_SIM_RECEIPT_SHA_FAIL'
}
$stagedImage = Join-Path $work 'rtl\core\neorv32_imem_image.vhd'
if ((Get-FileHash -LiteralPath $stagedImage -Algorithm SHA256).Hash -cne
    [string]$r.ImemImageSHA256) {
    throw 'LAB061_AUDIT_STAGED_IMEM_SHA_FAIL'
}
$stagedVerilog = Join-Path $work 'rtl\lab061_neorv32_top.v'
if ((Get-FileHash -LiteralPath $stagedVerilog -Algorithm SHA256).Hash -cne
    [string]$r.ConvertedVerilogSHA256) {
    throw 'LAB061_AUDIT_VERILOG_SHA_FAIL'
}
$manifestPath = Join-Path $job 'input_sha256.csv'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'LAB061_AUDIT_INPUT_MANIFEST_MISSING'
}
$rows = @(Import-Csv -LiteralPath $manifestPath)
if ($rows.Count -lt 40) { throw "LAB061_AUDIT_INPUT_MANIFEST_TOO_SHORT: $($rows.Count)" }
foreach ($row in $rows) {
    $staged = Join-Path $work ([string]$row.Path).Replace('/', '\')
    if (-not (Test-Path -LiteralPath $staged -PathType Leaf)) {
        throw "LAB061_AUDIT_INPUT_MISSING: $staged"
    }
    $hash = (Get-FileHash -LiteralPath $staged -Algorithm SHA256).Hash
    if ($hash -cne [string]$row.SHA256) {
        throw "LAB061_AUDIT_INPUT_HASH_CHANGED: $staged"
    }
}
Write-Host "LAB061_INPUT_SNAPSHOT_SHA_PASS: $($rows.Count) staged inputs + ROM + Verilog" -ForegroundColor Green

# The exact pin set matches independently accepted PicoRV32 constraints.
$expectedPins = [ordered]@{
    'clk_i'='52'; 'rstn_i'='3'; 'uart0_txd_o'='17'; 'uart0_rxd_i'='18'
    'led_n_o[0]'='10'; 'led_n_o[1]'='11'; 'led_n_o[2]'='13'
    'led_n_o[3]'='14'; 'led_n_o[4]'='15'; 'led_n_o[5]'='16'
}
$expectedTypes = [ordered]@{
    'clk_i'='LVCMOS33'; 'rstn_i'='LVCMOS18'
    'uart0_txd_o'='LVCMOS33'; 'uart0_rxd_i'='LVCMOS33'
    'led_n_o[0]'='LVCMOS18'; 'led_n_o[1]'='LVCMOS18'
    'led_n_o[2]'='LVCMOS18'; 'led_n_o[3]'='LVCMOS18'
    'led_n_o[4]'='LVCMOS18'; 'led_n_o[5]'='LVCMOS18'
}
$cstPath = Join-Path $work 'constraints\lab061_nano9k.cst'
$cst = Get-Content -LiteralPath $cstPath -Raw
$locMatches = [regex]::Matches($cst,'IO_LOC\s+"([^"]+)"\s+(\d+)\s*;')
$typeMatches = [regex]::Matches($cst,'IO_PORT\s+"([^"]+)"\s+IO_TYPE=(\w+)')
if ($locMatches.Count -ne $expectedPins.Count -or
    $typeMatches.Count -ne $expectedTypes.Count) {
    throw "LAB061_PIN_COUNT_FAIL: loc=$($locMatches.Count), types=$($typeMatches.Count)"
}
foreach ($pin in $expectedPins.Keys) {
    $hits = @($locMatches | Where-Object { $_.Groups[1].Value -ceq $pin })
    $types = @($typeMatches | Where-Object { $_.Groups[1].Value -ceq $pin })
    if ($hits.Count -ne 1 -or $types.Count -ne 1 -or
        $hits[0].Groups[2].Value -cne $expectedPins[$pin] -or
        $types[0].Groups[2].Value -cne $expectedTypes[$pin]) {
        throw "LAB061_PIN_FAIL: $pin"
    }
}
$sdc = (Get-Content -LiteralPath (Join-Path $work 'constraints\lab061_nano9k.sdc') -Raw).Trim()
if ($sdc -cne 'create_clock -name clk_i -period 37.037 -waveform {0 18.518} [get_ports {clk_i}]') {
    throw 'LAB061_CLK_CONSTRAINT_CHANGED'
}
Write-Host 'LAB061_PINS_27MHZ_PASS: 10 expected pins, IO types and 27MHz single-clock SDC' -ForegroundColor Green

# Validate ELECTRICAL I/O information from the FINAL PnR report, not merely CST.
# The first candidate incorrectly showed clk_i pin52 LVCMOS33 but BankVccio=1.2.
$expectedBankVccio = [ordered]@{
    'clk_i' = '3.3'
    'rstn_i' = '1.8'
    'uart0_txd_o' = '3.3'
    'uart0_rxd_i' = '3.3'
    'led_n_o[0]' = '1.8'
    'led_n_o[1]' = '1.8'
    'led_n_o[2]' = '1.8'
    'led_n_o[3]' = '1.8'
    'led_n_o[4]' = '1.8'
    'led_n_o[5]' = '1.8'
}
$pnrText = Get-Content -LiteralPath $reportPath -Raw
# Gowin versions vary between LF, CRLF and CR report line endings.
# Do not match output pins with a multiline anchored regex (not portable here).
# Instead identify exact first-column values in the 16-column "Port Name"
# table. Never match the separate bank table where the first column is "52/1".
$pnrLines = [regex]::Split($pnrText, '\r\n|\n|\r')
foreach ($port in $expectedPins.Keys) {
    $found = @(
        foreach ($line in $pnrLines) {
            if (-not $line.Contains('|')) { continue }
            $candidate = @($line.Split('|') | ForEach-Object { $_.Trim() })
            if ($candidate.Count -ge 2 -and $candidate[0] -ceq $port) {
                [PSCustomObject]@{ Cells = $candidate; Raw = $line }
            }
        }
    )
    if ($found.Count -ne 1) {
        $near = @(
            $pnrLines |
                Where-Object { $_.Contains($port) } |
                Select-Object -First 4
        )
        Write-Host "LAB061_PNR_PORT_DIAGNOSTIC: $port nearby=[$($near -join ' || ')]" -ForegroundColor Yellow
        throw "LAB061_PNR_PORT_NOT_UNIQUE: $port (rows=$($found.Count)); DO NOT PROGRAM"
    }
    $cell = @($found[0].Cells)
    # Gowin "Port Name | Diff Pair | Loc./Bank | ... | BankVccio":
    # 16 columns, zero-based indices: Loc=2, Constraint=3, IOType=6, VCCIO=15.
    if ($cell.Count -ne 16) {
        throw "LAB061_PNR_PORT_FORMAT_UNKNOWN: $port columns=$($cell.Count); DO NOT PROGRAM"
    }
    $portLoc = @($cell[2].Split('/'))
    if ($portLoc.Count -ne 2 -or
        $portLoc[0] -cne [string]$expectedPins[$port] -or
        $cell[3] -cne 'Y' -or
        $cell[6] -cne [string]$expectedTypes[$port]) {
        throw "LAB061_PNR_PORT_MAPPING_FAIL: $port loc=$($cell[2]) constraint=$($cell[3]) type=$($cell[6]); DO NOT PROGRAM"
    }
    if ($cell[15] -cne [string]$expectedBankVccio[$port]) {
        throw "LAB061_PNR_BANK_VCCIO_FAIL: $port pin=$($cell[2]) IOType=$($cell[6]) BankVccio=$($cell[15]) expected=$($expectedBankVccio[$port]); DO NOT PROGRAM"
    }
}
Write-Host 'LAB061_PNR_BANK_VCCIO_PASS: 10/10 fitted pins; report voltages verified' -ForegroundColor Green

if (-not (Select-String -LiteralPath $staLogPath -Pattern 'LAB061_STA_SCREEN_PRELIM_PASS' -Quiet)) {
    throw 'LAB061_AUDIT_STA_MARKER_MISSING'
}
& python (Join-Path $lab 'tools\check_sta_lab061.py') $timingPath --log $logPath
if ($LASTEXITCODE -ne 0) { throw 'LAB061_AUDIT_REPEAT_STA_FAIL' }

Write-Host "LAB061_RESOURCE_REPORT: $reportPath"
Write-Host 'LAB061_RESOURCE_EXCERPT_BEGIN'
$matches = @(Get-Content -LiteralPath $reportPath |
    Select-String -Pattern 'Logic|LUT|ALU|Register|FF|BSRAM|SDPB|DPB|DSP|PLL|I/O|IOB|Utilization|Resource')
foreach ($match in ($matches | Select-Object -First 65)) {
    Write-Host $match.Line
}
Write-Host 'LAB061_RESOURCE_EXCERPT_END'
if ($matches.Count -eq 0) { throw 'LAB061_RESOURCE_REPORT_HAS_NO_RECOGNIZED_ROWS' }

Write-Host "LAB061_INTERNAL_PREBOARD_AUDIT_PASS: $actual" -ForegroundColor Green
Write-Host 'LAB061_EXTERNAL_IO_TIMING: NOT CHARACTERIZED (UART RX asynchronous, reset external)' -ForegroundColor Yellow
Write-Host 'LAB061_BOARD: NOT RUN. No hardware action performed; full timing / reset review still required.'
