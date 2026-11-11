# SD-04.2 internal STA acceptance. Fail closed; never programs FPGA.
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)][string]$RunDir,
    [Parameter(Mandatory=$true)]
    [ValidatePattern('^[0-9A-Fa-f]{64}$')]
    [string]$ExpectedSHA256
)
$ErrorActionPreference='Stop'
$name='sd04_directory_nano9k'
$pnr=Join-Path $RunDir 'work\impl\pnr'
$fs=Join-Path $RunDir ($name+'.fs')
$report=Join-Path $pnr ($name+'_tr_content.html')
$resources=Join-Path $pnr ($name+'.rpt.txt')
$log=Join-Path $pnr ($name+'.log')
foreach($file in @($fs,$report,$resources,$log)){
    if(-not (Test-Path -LiteralPath $file -PathType Leaf)){
        throw ('SD04_STA_FAIL: missing '+$file)
    }
}
$actual=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToUpperInvariant()
if($actual -ne $ExpectedSHA256.ToUpperInvariant()){
    throw ("SD04_STA_FAIL: SHA mismatch expected=$ExpectedSHA256 actual=$actual")
}
Write-Host ('SD04_SHA256_PASS: '+$actual)

$html=Get-Content -LiteralPath $report -Raw
$rows=@(
    foreach($tr in [regex]::Matches($html,'(?is)<tr\b[^>]*>(.*?)</tr>')){
        $cells=@(
            foreach($td in [regex]::Matches($tr.Groups[1].Value,'(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')){
                $v=$td.Groups[1].Value -replace '(?is)<[^>]+>',' '
                $v=[System.Net.WebUtility]::HtmlDecode($v)
                ($v -replace '\s+',' ').Trim()
            }
        )
        if($cells.Count -gt 0){ $cells -join ' | ' }
    }
)
function Get-ExactViolationCount([string]$Label) {
    $lines=@($rows | Where-Object {$_ -match ('^Numbers of '+$Label+' Violated Endpoints\s*\|\s*\d+\s*$')})
    if($lines.Count -ne 1){throw ('SD04_STA_FAIL: unexpected '+$Label+' Violated Endpoints row count: '+$lines.Count)}
    if($lines[0] -notmatch '\|\s*(\d+)\s*$'){throw ('SD04_STA_FAIL: unparsable '+$Label+' count')}
    return [int]$Matches[1]
}
$setup=Get-ExactViolationCount 'Setup'
$hold=Get-ExactViolationCount 'Hold'
Write-Host "SD04_SETUP_VIOLATED_ENDPOINTS: $setup"
Write-Host "SD04_HOLD_VIOLATED_ENDPOINTS: $hold"
$tns=@{}
foreach($row in $rows){
    if($row -match '^\s*clk27\s*\|\s*(Setup|Hold)\s*\|\s*(-?\d+(?:\.\d+)?)\s*\|\s*(\d+)\s*$'){
        $type=$Matches[1]
        if($tns.ContainsKey($type)){throw ("SD04_STA_FAIL: duplicate clk27 "+$type+" TNS row")}
        $tns[$type]=[pscustomobject]@{
            Value=[double]::Parse($Matches[2],[Globalization.CultureInfo]::InvariantCulture)
            Endpoints=[int]$Matches[3]
        }
    }
}
foreach($type in @('Setup','Hold')){
    if(-not $tns.ContainsKey($type)){throw ("SD04_STA_FAIL: missing clk27 "+$type+" TNS row")}
    Write-Host ("SD04_"+$type+"_TNS_NS: "+$tns[$type].Value)
    Write-Host ("SD04_"+$type+"_TNS_ENDPOINTS: "+$tns[$type].Endpoints)
}
Write-Host ''
Write-Host '=== SD04 RESOURCE SUMMARY ==='
Select-String -LiteralPath $resources -Pattern 'Logic ','LUT,ALU','Logic Register as FF','BSRAM','DSP ','PLL ' |
    Select-Object -First 12 | ForEach-Object {Write-Host $_.Line}
Write-Host ''
Write-Host '=== SD04 FIRST SETUP PATHS ==='
$rows | Where-Object {$_ -match '\bclk27:\[R\]|\bclk27:\[F\]'} |
    Select-Object -First 8 | ForEach-Object {Write-Host $_}
Write-Host ''
Write-Host '=== SD04 PNR LOG ERROR STRINGS (informational) ==='
Select-String -LiteralPath $log -Pattern 'ERROR','CRITICAL','FAIL' |
    Select-Object -Last 15 | ForEach-Object {Write-Host $_.Line}

if($setup -ne 0 -or $hold -ne 0 -or
   $tns.Setup.Value -lt 0 -or $tns.Hold.Value -lt 0 -or
   $tns.Setup.Endpoints -ne 0 -or $tns.Hold.Endpoints -ne 0){
    throw ("SD04_STA_FAIL: setup=$setup hold=$hold setupTNS=$($tns.Setup.Value) holdTNS=$($tns.Hold.Value)")
}
Write-Host 'SD04_STA_PASS: internal clk27 timing gate passed.'
Write-Host 'NOTE: external SD MISO return timing is not fully characterized.'
Write-Host 'NOTE: this does not verify SD-04 functionality on real hardware.'
