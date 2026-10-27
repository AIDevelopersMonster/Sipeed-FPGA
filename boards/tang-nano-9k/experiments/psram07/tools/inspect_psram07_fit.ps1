#requires -Version 7.0
<#
LAB-07: inspect the EXACT Gowin PnR result that the operator already built.
READ ONLY: no synthesis, no local file writing, no USB/JTAG/SRAM/Flash.
This is an evidence extractor, NOT a PSRAM DDR timing-signoff tool.
#>
[CmdletBinding()]
param(
  [string]$FitJob = 'C:\GitHub\Sipeed-FPGA\boards\tang-nano-9k\experiments\psram07\_build\fit_20261027_101531_279',
  [ValidatePattern('^[A-Fa-f0-9]{64}
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$job = (Resolve-Path -LiteralPath $FitJob -ErrorAction Stop).Path
$top = 'psram07_nano9k'
$fs = Join-Path $job ($top + '.fs')
$receiptPath = Join-Path $job 'receipt.json'
$logPath = Join-Path $job 'gowin.log'
$pnr = Join-Path $job 'work\impl\pnr'
$reportPath = Join-Path $pnr ($top + '.rpt.txt')
$staPath = Join-Path $pnr ($top + '_tr_content.html')
$inputManifest = Join-Path $job 'input_sha256.csv'
foreach($p in @($fs,$receiptPath,$logPath,$reportPath,$staPath,$inputManifest)) {
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)) {
    throw "LAB07_AUDIT_FILE_MISSING: $p"
  }
}
$r=Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
if($r.Stage -cne 'LAB07_PSRAM_FIT_CANDIDATE' -or
   $r.Status -cne 'PNR_COMPLETED_STA_AND_PSRAM_IO_NOT_YET_AUDITED' -or
   $r.Hardware -cne 'NOT_RUN') {
  throw 'LAB07_AUDIT_RECEIPT_UNEXPECTED'
}
$realHash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if($realHash -cne $ExpectedSha.ToUpperInvariant() -or
   ([string]$r.BitstreamSHA256).ToUpperInvariant() -cne $ExpectedSha.ToUpperInvariant()) {
  throw "LAB07_AUDIT_BITSTREAM_SHA_MISMATCH: $realHash"
}
Write-Output "LAB07_EXACT_SHA256_PASS: $realHash"
Write-Output "LAB07_FIT_REPORT_PATH: $reportPath"
Write-Output "LAB07_STA_REPORT_PATH: $staPath"

$report = Get-Content -LiteralPath $reportPath -Raw
$rows = $report -split '\r?\n'
Write-Output '=== LAB07 RESOURCE SUMMARY (native Gowin report, NOT CPU/PSRAM validated) ==='
foreach($line in $rows) {
  if($line -match '^\s*(?:Logic|Register|BSRAM|DSP|PLL|I/O Port)\s*\|') {
    Write-Output $line.Trim()
  }
}
Write-Output '=== LAB07 PORT ASSIGNMENTS (physical and PSRAM special ports) ==='
$seen=0
foreach($line in $rows) {
  if($line -match '^\s*(?:sys_clk|sys_resetn|uart_txp|led\[|O_psram|IO_psram)' -and
     $line.Contains('|')) {
    Write-Output $line.Trim()
    $seen++
  }
}
Write-Output "LAB07_PORT_ROWS_PRINTED: $seen"
if($seen -lt 9) {
  Write-Output 'LAB07_PORT_TABLE_INCOMPLETE: STOP before FPGA programming.'
}

# Strip CSS/markup while retaining table cell boundaries.
$html = Get-Content -LiteralPath $staPath -Raw
$cleanHtml = [regex]::Replace($html,'(?is)<(?:script|style)\b[^>]*>.*?</(?:script|style)>',' ')
$cleanHtml = [regex]::Replace($cleanHtml,'(?is)</(?:tr|p|div|h[1-6]|table)\s*>',[string][char]10)
$plain = [System.Net.WebUtility]::HtmlDecode(
  [regex]::Replace($cleanHtml, '(?s)<[^>]*>', ' ')
)
$flat = [regex]::Replace($plain, '\s+', ' ').Trim()
Write-Output '=== LAB07 STA COUNT MARKERS ==='
$markers=@(
 'Numbers of Paths Analyzed',
 'Numbers of Endpoints Analyzed',
 'Numbers of Setup Violated Endpoints',
 'Numbers of Hold Violated Endpoints'
)
foreach($key in $markers) {
  $m=[regex]::Match($flat,[regex]::Escape($key)+'\s+(\d+)\b')
  if($m.Success){
    Write-Output ('LAB07_STA_COUNT: '+$key+' = '+$m.Groups[1].Value)
  }else{
    Write-Output ('LAB07_STA_MARKER_NOT_FOUND: '+$key)
  }
}
$setupViolations = [regex]::Match($flat,
  [regex]::Escape('Numbers of Setup Violated Endpoints')+'\s+(\d+)\b')
$holdViolations = [regex]::Match($flat,
  [regex]::Escape('Numbers of Hold Violated Endpoints')+'\s+(\d+)\b')
if(-not $setupViolations.Success -or -not $holdViolations.Success) {
  Write-Output 'LAB07_STA_GATE: BLOCKED_COUNTERS_MISSING'
} elseif([int]$setupViolations.Groups[1].Value -ne 0 -or
         [int]$holdViolations.Groups[1].Value -ne 0) {
  Write-Output 'LAB07_STA_GATE: FAIL_VIOLATED_ENDPOINTS'
} else {
  Write-Output 'LAB07_STA_GATE: ZERO_REPORTED_SETUP_HOLD_VIOLATIONS_ONLY_DDR_REVIEW_STILL_REQUIRED'
}
Write-Output '=== LAB07 CLOCKS / DERIVED 81MHz / TIMING SECTIONS ==='
$maxLen=650
foreach($section in @(
  'Clock Summary',
  'Timing Constraints Report:',
  'Setup Paths Table',
  'Hold Paths Table',
  'Recovery Paths Table',
  'Removal Paths Table'
)) {
  $at=$flat.IndexOf($section,[System.StringComparison]::OrdinalIgnoreCase)
  if($at -lt 0) {
    Write-Output "LAB07_STA_SECTION_MISSING: $section"
    continue
  }
  $length=[math]::Min($maxLen,$flat.Length-$at)
  Write-Output ('LAB07_STA_SECTION: '+ $flat.Substring($at,$length))
}
Write-Output '=== LAB07 PSRAM / PLL EVIDENCE ==='
$log = Get-Content -LiteralPath $logPath -Raw
$messages = @($log -split '\r?\n' | Where-Object {
  $_ -match '(?i)psram|clock|rpll|81\.0|warn|error|fatal|unconstrain|timing|not support'
} | Select-Object -First 65)
foreach($msg in $messages) {
  Write-Output $msg
}
if($messages.Count -eq 0){Write-Output 'LAB07_NO_MATCHING_GOWIN_LOG_LINES'}
$psramReportLines = @($rows | Where-Object {
  $_ -match '(?i)psram|rpll|Gowin'
} | Select-Object -First 35)
Write-Output '=== LAB07 PSRAM PNR DETAILS ==='
foreach($msg in $psramReportLines) {Write-Output $msg.Trim()}
Write-Output 'LAB07_AUDIT_EVIDENCE_COLLECTED: human review required for 81MHz PLL, DDR interface and timing coverage.'
Write-Output 'LAB07_HARDWARE_NOT_AUTHORIZED: do not program this candidate on this evidence alone.'
)]
  [string]$ExpectedSha = 'D3E38926012EC2C7E7762D69553446E1BBDC9B05038A68A24165E1C3F74EE21B'
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$job = (Resolve-Path -LiteralPath $FitJob -ErrorAction Stop).Path
$top = 'psram07_nano9k'
$expectedSha = 'D3E38926012EC2C7E7762D69553446E1BBDC9B05038A68A24165E1C3F74EE21B'
$fs = Join-Path $job ($top + '.fs')
$receiptPath = Join-Path $job 'receipt.json'
$logPath = Join-Path $job 'gowin.log'
$pnr = Join-Path $job 'work\impl\pnr'
$reportPath = Join-Path $pnr ($top + '.rpt.txt')
$staPath = Join-Path $pnr ($top + '_tr_content.html')
$inputManifest = Join-Path $job 'input_sha256.csv'
foreach($p in @($fs,$receiptPath,$logPath,$reportPath,$staPath,$inputManifest)) {
  if(-not(Test-Path -LiteralPath $p -PathType Leaf)) {
    throw "LAB07_AUDIT_FILE_MISSING: $p"
  }
}
$r=Get-Content -LiteralPath $receiptPath -Raw -Encoding utf8 | ConvertFrom-Json
if($r.Stage -cne 'LAB07_PSRAM_FIT_CANDIDATE' -or
   $r.Status -cne 'PNR_COMPLETED_STA_AND_PSRAM_IO_NOT_YET_AUDITED' -or
   $r.Hardware -cne 'NOT_RUN') {
  throw 'LAB07_AUDIT_RECEIPT_UNEXPECTED'
}
$realHash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if($realHash -cne $expectedSha -or
   [string]$r.BitstreamSHA256 -cne $expectedSha) {
  throw "LAB07_AUDIT_BITSTREAM_SHA_MISMATCH: $realHash"
}
Write-Output "LAB07_EXACT_SHA256_PASS: $realHash"
Write-Output "LAB07_FIT_REPORT_PATH: $reportPath"
Write-Output "LAB07_STA_REPORT_PATH: $staPath"

$report = Get-Content -LiteralPath $reportPath -Raw
$rows = $report -split '\r?\n'
Write-Output '=== LAB07 RESOURCE SUMMARY (native Gowin report, NOT CPU/PSRAM validated) ==='
foreach($line in $rows) {
  if($line -match '^\s*(?:Logic|Register|BSRAM|DSP|PLL|I/O Port)\s*\|') {
    Write-Output $line.Trim()
  }
}
Write-Output '=== LAB07 PORT ASSIGNMENTS (physical and PSRAM special ports) ==='
$seen=0
foreach($line in $rows) {
  if($line -match '^\s*(?:sys_clk|sys_resetn|uart_txp|led\[|O_psram|IO_psram)' -and
     $line.Contains('|')) {
    Write-Output $line.Trim()
    $seen++
  }
}
Write-Output "LAB07_PORT_ROWS_PRINTED: $seen"
if($seen -lt 9) {
  Write-Output 'LAB07_PORT_TABLE_INCOMPLETE: STOP before FPGA programming.'
}

# Strip CSS/markup while retaining table cell boundaries.
$html = Get-Content -LiteralPath $staPath -Raw
$cleanHtml = [regex]::Replace($html,'(?is)<(?:script|style)\b[^>]*>.*?</(?:script|style)>',' ')
$cleanHtml = [regex]::Replace($cleanHtml,'(?is)</(?:tr|p|div|h[1-6]|table)\s*>',[string][char]10)
$plain = [System.Net.WebUtility]::HtmlDecode(
  [regex]::Replace($cleanHtml, '(?s)<[^>]*>', ' ')
)
$flat = [regex]::Replace($plain, '\s+', ' ').Trim()
Write-Output '=== LAB07 STA COUNT MARKERS ==='
$markers=@(
 'Numbers of Paths Analyzed',
 'Numbers of Endpoints Analyzed',
 'Numbers of Setup Violated Endpoints',
 'Numbers of Hold Violated Endpoints'
)
foreach($key in $markers) {
  $m=[regex]::Match($flat,[regex]::Escape($key)+'\s+(\d+)\b')
  if($m.Success){
    Write-Output ('LAB07_STA_COUNT: '+$key+' = '+$m.Groups[1].Value)
  }else{
    Write-Output ('LAB07_STA_MARKER_NOT_FOUND: '+$key)
  }
}
Write-Output '=== LAB07 CLOCKS / DERIVED 81MHz / TIMING SECTIONS ==='
$maxLen=650
foreach($section in @(
  'Clock Summary',
  'Timing Constraints Report:',
  'Setup Paths Table',
  'Hold Paths Table',
  'Recovery Paths Table',
  'Removal Paths Table'
)) {
  $at=$flat.IndexOf($section,[System.StringComparison]::OrdinalIgnoreCase)
  if($at -lt 0) {
    Write-Output "LAB07_STA_SECTION_MISSING: $section"
    continue
  }
  $length=[math]::Min($maxLen,$flat.Length-$at)
  Write-Output ('LAB07_STA_SECTION: '+ $flat.Substring($at,$length))
}
Write-Output '=== LAB07 PSRAM / PLL EVIDENCE ==='
$log = Get-Content -LiteralPath $logPath -Raw
$messages = @($log -split '\r?\n' | Where-Object {
  $_ -match '(?i)psram|clock|rpll|81\.0|warn|error|fatal|unconstrain|timing|not support'
} | Select-Object -First 65)
foreach($msg in $messages) {
  Write-Output $msg
}
if($messages.Count -eq 0){Write-Output 'LAB07_NO_MATCHING_GOWIN_LOG_LINES'}
$psramReportLines = @($rows | Where-Object {
  $_ -match '(?i)psram|rpll|Gowin'
} | Select-Object -First 35)
Write-Output '=== LAB07 PSRAM PNR DETAILS ==='
foreach($msg in $psramReportLines) {Write-Output $msg.Trim()}
Write-Output 'LAB07_AUDIT_EVIDENCE_COLLECTED: human review required for 81MHz PLL, DDR interface and timing coverage.'
Write-Output 'LAB07_HARDWARE_NOT_AUTHORIZED: do not program this candidate on this evidence alone.'
