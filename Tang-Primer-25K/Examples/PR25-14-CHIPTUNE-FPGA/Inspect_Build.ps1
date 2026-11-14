#Requires -Version 7.0
# PR25-14 read-only report inspection. It never builds or programs the FPGA.
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$mf=Join-Path $root 'artifacts\PR25_14_manifest.json'
if(!(Test-Path -LiteralPath $mf)){throw "Missing build manifest: $mf"}
$m=Get-Content -LiteralPath $mf -Raw | ConvertFrom-Json
if($m.status -ne 'BUILD_PASS_STA_REVIEW_REQUIRED' -or $m.gowin_exit -ne 0){
    throw "Build not marked PASS: $($m.status), Gowin=$($m.gowin_exit)"
}
$expected='106f396912caf6c2c04fb9dede1c3bdd38dc46bb6a0556cd9c37b30ebdf82a98'
$fs=Join-Path $root 'artifacts\chipmusic_tp25k_PR25_14.fs'
if(!(Test-Path -LiteralPath $fs)){throw "Bitstream missing: $fs"}
$sha=(Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
if($sha -ne $expected -or $sha -ne $m.bitstream_sha256){
    throw "Unexpected PR25-14 .fs SHA256: $sha"
}
$src=[string]$m.source_root
$pnr=Join-Path $src 'impl\pnr'
$syn=Join-Path $src 'impl\gwsynthesis'
$sta=Join-Path $pnr 'chipmusic_tp25k_tr_content.html'
$rpt=Join-Path $pnr 'chipmusic_tp25k.rpt.txt'
$synrpt=Join-Path $syn 'chipmusic_tp25k_syn.rpt.html'
$netlist=Join-Path $syn 'chipmusic_tp25k.vg'
foreach($file in @($sta,$rpt,$synrpt,$netlist)){
    if(!(Test-Path -LiteralPath $file)){throw "Missing build report: $file"}
}
function Cell([string]$html) {
    $s=[regex]::Replace($html,'(?is)<[^>]+>',' ')
    $s=[Net.WebUtility]::HtmlDecode($s)
    return ([regex]::Replace($s,'\s+',' ')).Trim()
}
$staHtml=[IO.File]::ReadAllText($sta)
$synHtml=[IO.File]::ReadAllText($synrpt)
function TableRows([string]$html){
    foreach($tb in [regex]::Matches($html,'(?is)<table\b[^>]*>(.*?)</table>')){
        $rows=@(foreach($tr in [regex]::Matches($tb.Groups[1].Value,'(?is)<tr\b[^>]*>(.*?)</tr>')){
            $cells=@(foreach($td in [regex]::Matches($tr.Groups[1].Value,'(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')){
                Cell $td.Groups[1].Value
            })
            if($cells.Count -gt 0){,$cells}
        })
        if($rows.Count -gt 0) {
            [pscustomobject]@{Offset=$tb.Index;Header=($rows[0] -join ' | ');Rows=$rows}
        }
    }
}
$staTables=@(TableRows $staHtml)
$resourceRows=@(TableRows $synHtml | ForEach-Object { $_.Rows } |
    Where-Object { ($_ -join ' | ') -match '(?i)\b(BSRAM|LUT4|pROM|ROM|DPB|block\s*RAM|logic\s*utilization|registers)\b' } |
    ForEach-Object { ($_ -join ' | ') } |
    Select-Object -Unique -First 50)
$headings=@(foreach($h in [regex]::Matches($staHtml,'(?is)<h[1-4]\b[^>]*>(.*?)</h[1-4]>')){
    [pscustomobject]@{At=$h.Index;Text=(Cell $h.Groups[1].Value)}
})
$violations=@(foreach($tb in $staTables){
    if($tb.Header -notmatch 'Path Number' -or $tb.Header -notmatch 'Path Slack'){continue}
    $sections=@($headings | Where-Object {$_.At -lt $tb.Offset} | Select-Object -Last 1)
    $section=if($sections.Count -gt 0){$sections[0].Text}else{'Unknown'}
    foreach($row in @($tb.Rows | Select-Object -Skip 1)){
        if($row.Count -lt 6 -or $row[0] -notmatch '^\d+$'){continue}
        $slack=0.0
        if(![double]::TryParse($row[1],
          [Globalization.NumberStyles]::Float,
          [Globalization.CultureInfo]::InvariantCulture,[ref]$slack)){continue}
        if($slack -lt 0){
            [pscustomobject]@{Section=$section;SlackNs=$slack;From=$row[2];To=$row[3];FromClock=$row[4];ToClock=$row[5]}
        }
    }
})
$warnings=@(Get-Content -LiteralPath $rpt |
  Where-Object {$_ -match '(?i)TA1123|TA1117|Recovery|Removal|BSRAM|pROM' } |
  Select-Object -First 45)
$netlistText=[IO.File]::ReadAllText($netlist)
$prim=@(foreach($name in @('pROM','pROMX9','DPB','DPX9','SP','SPX9','SDPB','SDPX9')){
    $count=[regex]::Matches($netlistText,'(?im)^\s*'+[regex]::Escape($name)+'\s+(?:#\s*\(|[A-Za-z_\\])').Count
    if($count -gt 0){ "$name : $count" }
})
$summary=[System.Collections.Generic.List[string]]::new()
$summary.Add('PR25-14 CHIPMUSIC: READ-ONLY BUILD AUDIT')
$summary.Add("BITSTREAM SHA256: $sha")
$summary.Add("GLOBAL SETUP VIOLATIONS: $($m.global_setup_violations)")
$summary.Add("GLOBAL HOLD VIOLATIONS: $($m.global_hold_violations)")
$summary.Add("NEGATIVE PATHS IN SELECTED STA TABLES: $($violations.Count)")
foreach($v in $violations){$summary.Add(('{0}: slack={1} ns, {2} -> {3}, {4} => {5}' -f $v.Section,$v.SlackNs,$v.FromClock,$v.ToClock,$v.From,$v.To))}
$summary.Add('RESOURCE REPORT ROWS (actual numbers must be checked below):')
if($resourceRows.Count -eq 0){$summary.Add('None detected in synthesis HTML: check PnR .rpt.txt manually')}
foreach($row in $resourceRows){$summary.Add($row)}
$summary.Add('BRAM-TYPE PRIMITIVE INSTANCES IN SYNTHESIZED NETLIST:')
if($prim.Count -eq 0){$summary.Add('Not recognized by heuristic; use report resource table')}
foreach($row in $prim){$summary.Add($row)}
$summary.Add('TIMING/CLOCK/ROM LINES FROM PnR REPORT:')
foreach($line in $warnings){$summary.Add($line.Trim())}
$summary.Add('KNOWN LIMITS: Missing/cut paths and TA1123/TA1117 are not cleared by global Setup/Hold=0.')
$summary.Add('NO FPGA PROGRAM/BUILD/FLASH OPERATION PERFORMED.')
$ev=Join-Path $root 'evidence'
New-Item -ItemType Directory -Path $ev -Force | Out-Null
$out=Join-Path $ev ('PR25_14_READONLY_AUDIT_'+(Get-Date -Format 'yyyyMMdd_HHmmssfff')+'.txt')
$summary | Set-Content -LiteralPath $out -Encoding utf8
foreach($line in $summary){Write-Host $line}
Write-Host "AUDIT FILE: $out"
