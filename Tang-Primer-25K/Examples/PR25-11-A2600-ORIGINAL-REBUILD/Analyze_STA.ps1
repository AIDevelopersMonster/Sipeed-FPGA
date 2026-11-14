#Requires -Version 7.0
# PR25-11: READ-ONLY Gowin STA audit. NO build/JTAG/FPGA/Flash operations.
[CmdletBinding()]
param([int]$MaxPaths=30)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$manifest=Join-Path $PSScriptRoot 'artifacts\rebuild_manifest.json'
if (!(Test-Path -LiteralPath $manifest)){throw "Missing manifest: $manifest"}
$m=Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
if ($m.status -ne 'BUILD_PASS_NOT_BOARD_TESTED' -or
    $m.source_commit -ne '705bf787675579721d339806cb522905dec73ed3'){
    throw 'PR25-11 successful build manifest not found'
}
$pnr=Join-Path $m.workspace 'impl\pnr'
$report=Join-Path $pnr 'a2600nano_tp25k_tr_content.html'
$timing=Join-Path $pnr 'a2600nano_tp25k.timing_paths'
foreach($p in @($report,$timing)){
    if (!(Test-Path -LiteralPath $p)){throw "Missing report: $p"}
}
$html=[IO.File]::ReadAllText($report)
function Plain([string]$fragment){
    $str=[regex]::Replace($fragment,'(?is)<[^>]+>',' ')
    $str=[Net.WebUtility]::HtmlDecode($str)
    return ([regex]::Replace($str,'\s+',' ')).Trim()
}
function Num([string]$value){
    $match=[regex]::Match($value,'[-+]?\d+(?:\.\d+)?')
    if (!$match.Success){return $null}
    $v=0.0
    if([double]::TryParse($match.Value,[Globalization.NumberStyles]::Float,
        [Globalization.CultureInfo]::InvariantCulture,[ref]$v)){return $v}
    return $null
}
# Parse table rows as arrays, retaining the original HTML table offset.
$tables=[System.Collections.Generic.List[object]]::new()
foreach($tb in [regex]::Matches($html,'(?is)<table\b[^>]*>(.*?)</table>')){
    $rows=[System.Collections.Generic.List[object]]::new()
    foreach($tr in [regex]::Matches($tb.Groups[1].Value,'(?is)<tr\b[^>]*>(.*?)</tr>')){
        $cells=[System.Collections.Generic.List[string]]::new()
        foreach($td in [regex]::Matches($tr.Groups[1].Value,'(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')){
            $cells.Add((Plain $td.Groups[1].Value))
        }
        if($cells.Count -gt 0){$rows.Add($cells.ToArray())}
    }
    if($rows.Count -gt 0){
        $tables.Add([pscustomobject]@{Offset=$tb.Index;Header=($rows[0] -join '|');Rows=$rows.ToArray()})
    }
}
if($tables.Count -lt 3){throw 'Gowin HTML timing tables not recognized'}
$heads=[System.Collections.Generic.List[object]]::new()
foreach($h in [regex]::Matches($html,'(?is)<h[23]\b[^>]*>(.*?)</h[23]>')){
    $heads.Add([pscustomobject]@{Offset=$h.Index;Title=(Plain $h.Groups[1].Value)})
}
$globalSetup=$null; $globalHold=$null
$tns=[System.Collections.Generic.List[object]]::new()
$fmax=[System.Collections.Generic.List[object]]::new()
$paths=[System.Collections.Generic.List[object]]::new()
foreach($tb in $tables){
    foreach($row in $tb.Rows){
        if($row.Count -lt 2){continue}
        if($row[0] -eq 'Numbers of Setup Violated Endpoints'){$globalSetup=Num $row[1]}
        if($row[0] -eq 'Numbers of Hold Violated Endpoints'){$globalHold=Num $row[1]}
    }
    if($tb.Header -match 'Clock Name' -and $tb.Header -match 'Endpoints TNS'){
        foreach($row in @($tb.Rows | Select-Object -Skip 1)){
            if($row.Count -lt 4){continue}
            $value=Num $row[2]
            if($null -ne $value){
                $tns.Add([pscustomobject]@{Clock=$row[0];Analysis=$row[1];TNS=$value;Endpoints=(Num $row[3])})
            }
        }
    }
    if($tb.Header -match 'Clock Name' -and $tb.Header -match 'Actual Fmax'){
        foreach($row in @($tb.Rows | Select-Object -Skip 1)){
            if($row.Count -lt 4){continue}
            $target=Num $row[2];$actual=Num $row[3]
            if($null -ne $target -and $null -ne $actual){
                $fmax.Add([pscustomobject]@{Clock=$row[1];ConstraintMHz=$target;ActualMHz=$actual;Meets=($actual -ge $target)})
            }
        }
    }
    if($tb.Header -match 'Path Number' -and $tb.Header -match 'Path Slack' -and
        $tb.Header -match 'From Node' -and $tb.Header -match 'To Clock'){
        $prior=@($heads | Where-Object {$_.Offset -lt $tb.Offset} | Select-Object -Last 1)
        if($prior.Count -eq 0){continue}
        $heading=$prior[0].Title
        if($heading -notmatch '^(Setup|Hold|Recovery|Removal)\s+Paths\s+Table'){continue}
        $kind=$Matches[1]
        foreach($row in @($tb.Rows | Select-Object -Skip 1)){
            if($row.Count -lt 6){continue}
            $slack=Num $row[1];$index=Num $row[0]
            if($null -eq $slack -or $null -eq $index){continue}
            $a=$row[4] -replace ':\[[RF]\]\s*$',''
            $b=$row[5] -replace ':\[[RF]\]\s*$',''
            $paths.Add([pscustomobject]@{
                Kind=$kind;Path=[int]$index;SlackNs=$slack
                From=$row[2];To=$row[3];FromClock=$row[4];ToClock=$row[5]
                CrossClock=($a -ne $b)
            })
        }
    }
}
$setup=@($paths | Where-Object {$_.Kind -eq 'Setup'} | Sort-Object SlackNs)
$negative=@($paths | Where-Object {$_.SlackNs -lt 0} | Sort-Object SlackNs)
$cross=@($paths | Where-Object {$_.CrossClock} | Sort-Object SlackNs)
$badTns=@($tns | Where-Object {$_.TNS -lt 0 -or $_.Endpoints -gt 0})
$reason=if($globalSetup -gt 0 -and $negative.Count -eq 0){
    'Global setup violations NOT identified by the selected path tables. Original SDC filters -from_clock/-to_clock clk* and limits -max_paths 25; inspect full reports or request unfiltered STA.'
}elseif($negative.Count -gt 0){
    'Negative paths found in selected tables; use their clock pairs and endpoints to investigate.'
}else{
    'No negative paths in selected tables. Cannot infer board timing closure from a partial report.'
}
$ev=Join-Path $PSScriptRoot 'evidence'
New-Item -Path $ev -ItemType Directory -Force | Out-Null
$base=Join-Path $ev ('PR25_11_STA_AUDIT_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff'))
$txt=$base+'.txt';$json=$base+'.json';$zip=$base+'.zip'
[ordered]@{
    project='PR25-11';at=(Get-Date).ToString('o');source_commit=$m.source_commit
    source_report=$report;source_timing_paths=$timing
    report_sha256=(Get-FileHash -LiteralPath $report -Algorithm SHA256).Hash
    timing_paths_sha256=(Get-FileHash -LiteralPath $timing -Algorithm SHA256).Hash
    global_setup_violated=$globalSetup;global_hold_violated=$globalHold
    tns=$tns.ToArray();fmax=$fmax.ToArray()
    path_table_setup=$setup;path_table_negative=$negative;path_table_cross_clock=$cross
    conclusion=$reason
    status='READ_ONLY_REPORTS; NO_NEW_STA_ANALYSIS'
}|ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $json -Encoding utf8
$lines=[System.Collections.Generic.List[string]]::new()
$lines.Add('PR25-11 STATIC TIMING FORENSIC SUMMARY (READ-ONLY)')
$lines.Add("Global SETUP violated endpoints: $globalSetup")
$lines.Add("Global HOLD violated endpoints: $globalHold")
$lines.Add("Clock TNS negative rows: $($badTns.Count) of $($tns.Count)")
$lines.Add("Selected setup paths: $($setup.Count)")
$lines.Add("Negative paths listed: $($negative.Count)")
$lines.Add("Cross-clock paths listed: $($cross.Count)")
$lines.Add("Interpretation: $reason")
$lines.Add('')
$lines.Add('Worst selected Setup paths (may NOT include three global failures):')
foreach($p in @($setup | Select-Object -First $MaxPaths)){
    $lines.Add(('{0,2} {1,8:N3} ns | {2} -> {3} | {4} -> {5}' -f $p.Path,$p.SlackNs,$p.FromClock,$p.ToClock,$p.From,$p.To))
}
$lines.Add('')
$lines.Add('Negative selected paths:')
if($negative.Count -eq 0){$lines.Add('NONE SELECTED (does not override global failure count)')}
foreach($p in $negative){
    $lines.Add(('{0}: {1} ns {2} => {3} {4} -> {5}' -f $p.Kind,$p.SlackNs,$p.FromClock,$p.ToClock,$p.From,$p.To))
}
$lines.Add('')
$lines.Add('Fmax summary:')
foreach($f in $fmax){
    $lines.Add(('{0} constraint={1}MHz actual={2}MHz pass={3}' -f $f.Clock,$f.ConstraintMHz,$f.ActualMHz,$f.Meets))
}
$lines.Add('')
$lines.Add('Known hardware: Golden VIDEO+AUDIO PASS; Rebuilt VIDEO+AUDIO FAIL.')
$lines | Set-Content -LiteralPath $txt -Encoding utf8
foreach($line in $lines){Write-Host $line}
Compress-Archive -LiteralPath @($report,$timing,$json,$txt) -DestinationPath $zip -Force
Write-Host ''
Write-Host "REPORTS ZIP: $zip"
Write-Host "LOCAL SUMMARY: $txt"
Write-Host 'Upload REPORTS ZIP to this chat for exact endpoint analysis.'
