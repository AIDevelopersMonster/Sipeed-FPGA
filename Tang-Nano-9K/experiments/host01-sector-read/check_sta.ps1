# HOST-01 timing gate, no hardware programming.
[CmdletBinding()]
param(
 [Parameter(Mandatory=$true)][string]$RunDir,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-Fa-f]{64}$')][string]$ExpectedSHA256
)
$ErrorActionPreference='Stop'
$name='host01_sector_nano9k'
$pnr=Join-Path $RunDir 'work\impl\pnr'
$fs=Join-Path $RunDir ($name+'.fs')
$htmlPath=Join-Path $pnr ($name+'_tr_content.html')
$rpt=Join-Path $pnr ($name+'.rpt.txt')
foreach($p in @($fs,$htmlPath,$rpt)){
 if(-not (Test-Path -LiteralPath $p -PathType Leaf)){throw ('HOST01_STA_FAIL missing '+$p)}
}
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if($sha -ne $ExpectedSHA256.ToUpperInvariant()){throw ('HOST01_STA_FAIL SHA256 mismatch '+$sha)}
Write-Host ('HOST01_SHA256_PASS: '+$sha)
$html=Get-Content -LiteralPath $htmlPath -Raw
$rows=@(foreach($tr in [regex]::Matches($html,'(?is)<tr\b[^>]*>(.*?)</tr>')){
 $cells=@(foreach($td in [regex]::Matches($tr.Groups[1].Value,'(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')){
  $v=[System.Net.WebUtility]::HtmlDecode(($td.Groups[1].Value -replace '(?is)<[^>]+>',' '))
  ($v -replace '\s+',' ').Trim()
 })
 if($cells.Count){$cells -join ' | '}
})
$counts=@{}
foreach($which in @('Setup','Hold')){
 $rr=@($rows | Where-Object {$_ -match ('^Numbers of '+$which+' Violated Endpoints\s*\|\s*\d+\s*$')})
 if($rr.Count -ne 1){throw ('HOST01_STA_FAIL missing/ambiguous violations '+$which)}
 $counts[$which]=[int](($rr[0] -split '\|')[-1].Trim())
 Write-Host ('HOST01_'+$which+'_VIOLATIONS: '+$counts[$which])
}
$tns=@{}
foreach($row in $rows){
 if($row -match '^clk27\s*\|\s*(Setup|Hold)\s*\|\s*(-?\d+(?:\.\d+)?)\s*\|\s*(\d+)\s*$'){
  $k=$Matches[1]
  if($tns.ContainsKey($k)){throw ('HOST01_STA_FAIL duplicate TNS '+$k)}
  $tns[$k]=@([double]::Parse($Matches[2],[Globalization.CultureInfo]::InvariantCulture),[int]$Matches[3])
 }
}
foreach($k in @('Setup','Hold')){
 if(-not $tns.ContainsKey($k)){throw ('HOST01_STA_FAIL missing TNS '+$k)}
 Write-Host ('HOST01_'+$k+'_TNS_NS: '+$tns[$k][0])
 Write-Host ('HOST01_'+$k+'_TNS_ENDPOINTS: '+$tns[$k][1])
}
Write-Host '=== RESOURCES ==='
Select-String -LiteralPath $rpt -Pattern 'Logic ','LUT,ALU','Logic Register as FF','BSRAM','DSP ','PLL ' |
 Select-Object -First 12 | ForEach-Object {Write-Host $_.Line}
Write-Host '=== FIRST TIMING PATHS ==='
$rows | Where-Object {$_ -match '\bclk27:\[R\]|\bclk27:\[F\]'} |
 Select-Object -First 8 | ForEach-Object {Write-Host $_}
if($counts.Setup -ne 0 -or $counts.Hold -ne 0 -or
 $tns.Setup[0] -lt 0 -or $tns.Hold[0] -lt 0 -or
 $tns.Setup[1] -ne 0 -or $tns.Hold[1] -ne 0){
 throw 'HOST01_STA_FAIL: timing gate did not pass'
}
$cst=Join-Path $RunDir 'work\constraints\host01_nano9k.cst'
if(-not (Test-Path -LiteralPath $cst)){throw 'HOST01_STA_FAIL: CST missing'}
$raw=Get-Content -LiteralPath $cst -Raw
foreach($s in @('IO_LOC "clk" 52;','IO_LOC "reset_n" 3;','IO_LOC "uart_tx" 17;','IO_LOC "uart_rx" 18;','IO_LOC "sd_sck" 36;','IO_LOC "sd_mosi" 37;','IO_LOC "sd_cs_n" 38;','IO_LOC "sd_miso" 39;')){
 if(-not $raw.Contains($s)){throw ('HOST01_STA_FAIL: pin missing '+$s)}
}
Write-Host 'HOST01_STA_PASS: internal clk27 timing, SHA256, pins.'
Write-Host 'NOTE: async UART RX and external SD MISO timing are not fully phase-characterized.'
Write-Host 'NOTE: no FPGA functional hardware acceptance yet.'
