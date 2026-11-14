#Requires -Version 7.0
# PR25-13: same RTL as PR25-12; only x5 SDC waveform 1ns -> 50 percent.
# Never programs FPGA/Flash, and never edits the original Git checkout.
[CmdletBinding()]
param([string]$GowinShell='C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$expected='705bf787675579721d339806cb522905dec73ed3'
$expectedSerializerSha='0cd0a05bdfa74fb67fbee68971bf9586ee9db0b3'
$art=Join-Path $PSScriptRoot 'artifacts'
$work=Join-Path $PSScriptRoot 'work'
$evidence=Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $art,$work,$evidence | Out-Null
$manifest=Join-Path $art 'sdc50_manifest.json'
$stamp=Get-Date -Format 'yyyyMMdd_HHmmssfff'
@{status='STARTED';utc=(Get-Date).ToUniversalTime().ToString('o')} |
  ConvertTo-Json | Set-Content -LiteralPath $manifest -Encoding utf8
if (!(Test-Path -LiteralPath $GowinShell)){throw "Missing Gowin: $GowinShell"}
if (!(Get-Command git -ErrorAction SilentlyContinue)){throw 'Git not found'}
$previous=Join-Path $PSScriptRoot '..\PR25-11-A2600-ORIGINAL-REBUILD\_cache\A2600Nano-v2.5'
$ownCache=Join-Path $PSScriptRoot '_cache\A2600Nano-v2.5'
if (Test-Path -LiteralPath (Join-Path $previous '.git')) {
    $cache=$previous
} else {
    $cache=$ownCache
    if (!(Test-Path -LiteralPath (Join-Path $cache '.git'))) {
        New-Item -Path (Split-Path -Parent $cache) -ItemType Directory -Force | Out-Null
        & git clone --depth 1 --branch v2.5 'https://github.com/MiSTle-Dev/A2600Nano.git' $cache
        if ($LASTEXITCODE -ne 0){throw 'git clone failed'}
    }
}
$actual=(& git -C $cache rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
    throw "Upstream version mismatch, expected $expected got $actual"
}
$dirty=@(& git -C $cache status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
    throw 'Tracked source files modified; only pristine upstream cache allowed'
}
$run=Join-Path $work ('run_'+$stamp)
$source=Join-Path $run 'src'
$zip=Join-Path $run 'upstream_v25.zip'
New-Item -ItemType Directory -Force -Path $run,$source | Out-Null
& git -C $cache archive --format=zip --output=$zip HEAD
if ($LASTEXITCODE -ne 0){throw 'git archive failed'}
Expand-Archive -LiteralPath $zip -DestinationPath $source -Force

$rtlPath=Join-Path $source 'src\hdmi\serializer.sv'
$rtlText=[IO.File]::ReadAllText($rtlPath)
$serialOriginal=(Get-FileHash -LiteralPath $rtlPath -Algorithm SHA256).Hash.ToLowerInvariant()
# Upstream source is pinned by commit and the exact relevant port anchors.
$portPattern='\.RESET\(\s*reset\s*\)'
$portCount=[regex]::Matches($rtlText,$portPattern).Count
$anchor='        OSER10 gwSer0('
if ($portCount -ne 3 -or $rtlText.IndexOf($anchor,[StringComparison]::Ordinal) -lt 0) {
    throw "Unexpected serializer revision: expected 3 OSER10 reset ports, found $portCount"
}
$logic=@'
        // PR25-13 experiment: assert serializer reset asynchronously but
        // release in the x5 (FCLK) domain through three stages. Original
        // TMDS encoder, clock, packetizer, PLL and video timing are intact.
        (* syn_keep = "true" *) reg [2:0] oser_reset_pipe = 3'b111;
        always @(posedge clk_pixel_x5 or posedge reset) begin
            if (reset)
                oser_reset_pipe <= 3'b111;
            else
                oser_reset_pipe <= {oser_reset_pipe[1:0], 1'b0};
        end
        wire oser_reset_x5 = oser_reset_pipe[2];

'@
$rtlText=$rtlText.Replace($anchor,$logic+$anchor)
$rtlText=[regex]::Replace($rtlText,$portPattern,'.RESET( oser_reset_x5 )')
if ([regex]::Matches($rtlText,'\.RESET\(\s*oser_reset_x5\s*\)').Count -ne 3) {
    throw 'Reset port replacement count not exactly three'
}
[IO.File]::WriteAllText($rtlPath,$rtlText,[Text.UTF8Encoding]::new($false))
$serialPatched=(Get-FileHash -LiteralPath $rtlPath -Algorithm SHA256).Hash.ToLowerInvariant()

# PR25-13 SINGLE DELTA relative to PR25-12: correct the x5 clock
# waveform to an assumed 50%-duty cycle in a copied SDC file.
# This changes ONLY static timing modelling and potentially PnR placement.
# Do not silently change the period (6.984 ns); do not touch upstream cache.
$sdcPath=Join-Path $source 'src\tang\primer25k\a2600_top_tp25k.sdc'
$beforeSdcHash=(Get-FileHash -LiteralPath $sdcPath -Algorithm SHA256).Hash.ToLowerInvariant()
$originalSdcText=[IO.File]::ReadAllText($sdcPath)
$oldLine='create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 1} [get_nets {clk_pixel_x5}] -add'
$newLine='create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 3.492} [get_nets {clk_pixel_x5}] -add'
$matches=[regex]::Matches($originalSdcText,[regex]::Escape($oldLine)).Count
if ($matches -ne 1) {
    throw "Expected exactly one original x5 SDC waveform line; found $matches"
}
$patchedSdcText=$originalSdcText.Replace($oldLine,$newLine)
[IO.File]::WriteAllText($sdcPath,$patchedSdcText,[Text.UTF8Encoding]::new($false))
$afterSdcHash=(Get-FileHash -LiteralPath $sdcPath -Algorithm SHA256).Hash.ToLowerInvariant()

# Only known compatibility change, identical to successful PR25-11:
# Gowin 1.9.9Beta-4 refuses the author's set_option -loading_rate 70.000.
$upstreamTcl=Join-Path $source 'build_tp25k.tcl'
$tcl=[IO.File]::ReadAllText($upstreamTcl)
$tclPattern='(?m)^[ \t]*set_option[ \t]+-loading_rate[ \t]+70\.000[ \t]*(?:\r?\n|$)'
if ([regex]::Matches($tcl,$tclPattern).Count -ne 1) {
    throw 'Unexpected upstream loading_rate option'
}
$tcl=[regex]::Replace($tcl,$tclPattern,
    '# Gowin 1.9.9 compatibility: loading-rate option omitted'+[Environment]::NewLine)
$tclName='build_tp25k_compat199.tcl'
$tclPath=Join-Path $source $tclName
[IO.File]::WriteAllText($tclPath,$tcl,[Text.UTF8Encoding]::new($false))
$log=Join-Path $evidence ('PR25_13_BUILD_'+$stamp+'.log')
Write-Host 'PR25-13: upstream v2.5 + PR25-12 serializer reset sync + SDC x5 duty-50 diagnostic'
Write-Host "SOURCE: $actual"
Write-Host "serializer SHA BEFORE: $serialOriginal"
Write-Host "serializer SHA AFTER:  $serialPatched"
Write-Host 'Original build TCL remains unmodified; compatibility TCL omits loading_rate=70.000.'
Write-Host 'Only relative-to-PR25-12 change: SDC clk_pixel_x5 waveform {0 1} -> {0 3.492}.'
Write-Host "SDC SHA before: $beforeSdcHash"
Write-Host "SDC SHA after:  $afterSdcHash"
Write-Host "LOG: $log"
$started=[DateTime]::UtcNow
Push-Location $source
try {
    & $GowinShell $tclName 2>&1 | Tee-Object -FilePath $log
    $exitCode=$LASTEXITCODE
}
finally {Pop-Location}
Write-Host "GOWIN EXIT: $exitCode"
if ($exitCode -ne 0){throw 'PR25-13 synthesis/PnR failed, do NOT program'}
$fs=Join-Path $source 'impl\pnr\a2600nano_tp25k.fs'
if (!(Test-Path -LiteralPath $fs)){throw 'No compiled bitstream'}
$item=Get-Item -LiteralPath $fs
if ($item.Length -lt 100000 -or $item.LastWriteTimeUtc -lt $started.AddSeconds(-5)){
    throw 'Bitstream stale or too small'
}
$out=Join-Path $art 'a2600nano_tp25k_SDC50.fs'
Copy-Item -LiteralPath $fs -Destination $out -Force
$fsSha=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLowerInvariant()
$timingHtml=Join-Path $source 'impl\pnr\a2600nano_tp25k_tr_content.html'
$negativeRecovery=@()
if (Test-Path -LiteralPath $timingHtml) {
    $h=[IO.File]::ReadAllText($timingHtml)
    $section=[regex]::Match($h,
      '(?is)<h3><a name="Recovery_Slack_Table".*?(?=<h3><a name="Removal_Slack_Table")').Value
    $parsed=foreach($tr in [regex]::Matches($section,'(?is)<tr\b[^>]*>(.*?)</tr>')){
        $cells=@(foreach($td in [regex]::Matches($tr.Groups[1].Value,
             '(?is)<t[dh]\b[^>]*>(.*?)</t[dh]>')){
            ([Net.WebUtility]::HtmlDecode([regex]::Replace(
                  $td.Groups[1].Value,'(?is)<[^>]+>',' '))).Trim()
        })
        if($cells.Count -ge 6 -and $cells[0] -match '^\d+$' -and
           $cells[1] -match '^\s*-\d'){
            ($cells -join ' | ')
        }
    }
    $negativeRecovery=@($parsed)
}
[ordered]@{
  status='BUILD_PASS_STA_REVIEW_REQUIRED'
  source_commit=$expected;test='PR25-12 same OSER10 reset sync, with x5 clock waveform 50 percent (SDC only)'
  original_serializer_sha256=$serialOriginal
  patched_serializer_sha256=$serialPatched
  original_sdc_sha256=$beforeSdcHash
  patched_sdc_sha256=$afterSdcHash
  clock_x5_waveform_before='{0 1}'
  clock_x5_waveform_after='{0 3.492}'
  clock_x5_period_ns='6.984'
  sdc_assumption='50pct x5 duty assumed from PLL; must verify against hardware/tool'
  source_original_tcl='build_tp25k.tcl'
  source_compat_tcl=$tclName
  workspace=$source;bitstream=$out;bitstream_size=$item.Length
  bitstream_sha256=$fsSha
  build_log=$log;timing_html=$timingHtml
  negative_recovery_selected=$negativeRecovery
  board='NOT_TESTED';sta='NOT_VERIFIED'
}|ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifest -Encoding utf8
Write-Host "BUILD PASS: $out"
Write-Host "SHA256: $fsSha"
Write-Host "Negative Recovery paths selected: $($negativeRecovery.Count)"
foreach($r in $negativeRecovery){Write-Host $r}
Write-Host "Manifest: $manifest"
Write-Host 'DO NOT PROGRAM before checking ALL setup/recovery/removal timing and PLL messages.'
