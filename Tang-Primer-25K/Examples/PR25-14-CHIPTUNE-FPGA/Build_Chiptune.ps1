#Requires -Version 7.0
# PR25-14 original chiptune pixel-art HDMI demo.
# Reuses exact known-working PR25-13 HDL/PLL/OSER10 serializer as baseline.
# Does not program FPGA/Flash. Works without SDRAM/SD/USB keyboard.
[CmdletBinding()]
param([string]$GowinShell='C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe')
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$previous=Join-Path $root '..\PR25-13-A2600-SDC-DUTY50'
$previousManifest=Join-Path $previous 'artifacts\sdc50_manifest.json'
if(!(Test-Path -LiteralPath $previousManifest)){
    throw "Required verified PR25-13 build manifest missing: $previousManifest"
}
$m=Get-Content -LiteralPath $previousManifest -Raw | ConvertFrom-Json
$baseline='22cabb286d0b2ffb0973ae5109c872239782d341cfe46a8792921ed5be37580a'
if($m.status -ne 'BUILD_PASS_STA_REVIEW_REQUIRED' -or
   $m.source_commit -ne '705bf787675579721d339806cb522905dec73ed3' -or
   $m.bitstream_sha256 -ne $baseline){
    throw 'PR25-13 baseline build provenance mismatch; refuse to build'
}
$baseRoot=[string]$m.workspace
$baseRtl=Join-Path $baseRoot 'src\hdmi\serializer.sv'
$baseSdc=Join-Path $baseRoot 'src\tang\primer25k\a2600_top_tp25k.sdc'
if(!(Test-Path -LiteralPath $baseRtl) -or !(Test-Path -LiteralPath $baseSdc)){
    throw "PR25-13 source tree missing: $baseRoot"
}
$serSha=(Get-FileHash -LiteralPath $baseRtl -Algorithm SHA256).Hash.ToLowerInvariant()
if($serSha -ne '099529af001af82c11dabc19ee238629131ba82eaed6c37c64fd2a0ab9fe30a4'){
    throw "Not the PR25-13 reset-synchronized serializer: $serSha"
}
if(!(Test-Path -LiteralPath $GowinShell)){throw "Missing Gowin shell: $GowinShell"}
$work=Join-Path $root 'work';$art=Join-Path $root 'artifacts';$ev=Join-Path $root 'evidence'
New-Item -ItemType Directory -Path $work,$art,$ev -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmssfff'
$project=Join-Path $work ('run_'+$stamp+'\src')
New-Item -ItemType Directory -Path $project -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $baseRoot 'src') -Destination $project -Recurse -Force
Copy-Item -LiteralPath (Join-Path $baseRoot 'build_tp25k_compat199.tcl') -Destination $project -Force
$custom=Join-Path $project 'src'
foreach($name in @('chipmusic_top.vhd','chipmusic_video.sv','chipmusic_audio.sv','chipmusic_scene.sv')){
    Copy-Item -LiteralPath (Join-Path $root ('src\'+$name)) -Destination (Join-Path $custom $name) -Force
}
# Add deterministic display coordinates to a local copy of upstream HDMI.
$hdmiPath=Join-Path $custom 'hdmi\hdmi.sv'
$hdmi=[IO.File]::ReadAllText($hdmiPath)
$anchor='    // These outputs go to your HDMI port'
if([regex]::Matches($hdmi,[regex]::Escape($anchor)).Count -ne 1){throw 'Unexpected HDMI port anchor'}
$hdmi=$hdmi.Replace($anchor,"    output logic [10:0] next_pixel_x,`n    output logic [9:0] next_pixel_y,`n`n"+$anchor)
$pos='reg [9:0] cy;'
if([regex]::Matches($hdmi,[regex]::Escape($pos)).Count -ne 1){throw 'Unexpected HDMI counter anchor'}
$inject=@'

// PR25-14: prefetch the NEXT pixel coordinates into registered ROM;
// RGB produced by ROM is consumed during the following pixel clock.
assign next_pixel_x = (cx == frame_width - 1'b1) ? 11'd0 : cx + 1'b1;
assign next_pixel_y = (cx == frame_width - 1'b1) ?
    ((cy == frame_height - 1'b1) ? 10'd0 : cy + 1'b1) : cy;
'@
$hdmi=$hdmi.Replace($pos,$pos+$inject)
[IO.File]::WriteAllText($hdmiPath,$hdmi,[Text.UTF8Encoding]::new($false))

# Decode RGB888 palette and 160x90 8-bit image indices to synthesizer ROM files.
$asset=(Get-Content -LiteralPath (Join-Path $root 'assets\scene_zlib.b64') -Raw).Trim()
[byte[]]$packed=[Convert]::FromBase64String($asset)
$compressed=New-Object IO.MemoryStream(,$packed)
$unpack=[IO.Compression.ZLibStream]::new($compressed,[IO.Compression.CompressionMode]::Decompress)
$buff=[IO.MemoryStream]::new()
try{$unpack.CopyTo($buff)}finally{$unpack.Dispose();$compressed.Dispose()}
[byte[]]$raw=$buff.ToArray();$buff.Dispose()
if($raw.Length -ne (192+160*90)){throw "Unexpected image byte count $($raw.Length)"}
$shaRaw=([Security.Cryptography.SHA256]::HashData($raw)|ForEach-Object {$_.ToString('x2')}) -join ''
if($shaRaw -ne 'f54154294533176a85f0bae30fecfa030c7860950864de7e5f1758ff48e4f48c'){
    throw "ROM asset SHA256 mismatch: $shaRaw"
}
[string[]]$paletteLines=for($i=0;$i -lt 192;$i+=3){
    ('{0:x2}{1:x2}{2:x2}' -f $raw[$i],$raw[$i+1],$raw[$i+2])
}
[string[]]$pixelLines=for($i=192;$i -lt $raw.Length;$i++){$raw[$i].ToString('x2')}
[IO.File]::WriteAllLines((Join-Path $project 'scene_palette.mem'),$paletteLines)
[IO.File]::WriteAllLines((Join-Path $project 'scene_pixels.mem'),$pixelLines)

# New top has only HDMI, PLL and LEDs. Keep exactly proven connector pins.
$cst=@'
NET_LOC "jtagseln" V_JTAGSELN;
IO_PORT "jtagseln" PULL_MODE=DOWN IO_TYPE=LVCMOS33 BANK_VCCIO=3.3;
IO_LOC "clk_50mhz" E2;
IO_PORT "clk_50mhz" IO_TYPE=LVCMOS33 PULL_MODE=NONE DRIVE=OFF BANK_VCCIO=3.3;
IO_LOC "tmds_clk_p" H5,J5;
IO_PORT "tmds_clk_p" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC "tmds_d_p[0]" H8,H7;
IO_PORT "tmds_d_p[0]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC "tmds_d_p[1]" G7,G8;
IO_PORT "tmds_d_p[1]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC "tmds_d_p[2]" F5,G5;
IO_PORT "tmds_d_p[2]" PULL_MODE=NONE DRIVE=8 IO_TYPE=LVCMOS33D;
IO_LOC "leds_n[1]" E8;
IO_PORT "leds_n[1]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
IO_LOC "leds_n[0]" D7;
IO_PORT "leds_n[0]" IO_TYPE=LVCMOS33 PULL_MODE=UP;
'@
$sdctext=@'
create_clock -name clk_50mhz -period 20.000 -waveform {0 10} [get_ports {clk_50mhz}]
create_clock -name clk -period 34.921 -waveform {0 5} [get_nets {clk}]
create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 3.492} [get_nets {clk_pixel_x5}] -add
create_clock -name clk_audio -period 20833 -waveform {0 5} [get_nets {video_inst/clk_audio}] -add
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 100 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 100 -max_common_paths 1
'@
[IO.File]::WriteAllText((Join-Path $project 'chipmusic.cst'),$cst,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $project 'chipmusic.sdc'),$sdctext,[Text.UTF8Encoding]::new($false))
$tclPath=Join-Path $project 'build_tp25k_compat199.tcl'
$tcl=[IO.File]::ReadAllText($tclPath)
$tcl=$tcl.Replace('set_option -top_module A2600_top','set_option -top_module chipmusic_top')
$tcl=$tcl.Replace('set_option -output_base_name a2600nano_tp25k','set_option -output_base_name chipmusic_tp25k')
$tcl=$tcl.Replace('add_file src/tang/primer25k/a2600_top_tp25k.cst','add_file chipmusic.cst')
$tcl=$tcl.Replace('add_file src/tang/primer25k/a2600_top_tp25k.sdc','add_file chipmusic.sdc')
$tcl=$tcl.Replace('set_option -user_code 00000001','set_option -user_code 00000014')
$anchor='add_file src/hdmi/hdmi.sv'
if([regex]::Matches($tcl,[regex]::Escape($anchor)).Count -ne 1){throw 'TCL HDMI anchor absent'}
$tcl=$tcl.Replace($anchor,$anchor+[Environment]::NewLine+(@(
  'add_file src/chipmusic_top.vhd',
  'add_file src/chipmusic_video.sv',
  'add_file src/chipmusic_audio.sv',
  'add_file src/chipmusic_scene.sv') -join [Environment]::NewLine))
foreach($v in @('set_option -top_module chipmusic_top','add_file chipmusic.cst','add_file chipmusic.sdc','add_file src/chipmusic_scene.sv')){
    if(!$tcl.Contains($v)){throw "TCL patch missing: $v"}
}
[IO.File]::WriteAllText($tclPath,$tcl,[Text.UTF8Encoding]::new($false))
$log=Join-Path $ev ('PR25_14_BUILD_'+$stamp+'.log')
Write-Host 'PR25-14: independent pixel ROM scene and FPGA-synthesized chiptune'
Write-Host 'Source: exact PR25-13 working serializer/PLL/HDMI baseline; new top in isolated copy'
Write-Host 'ROM 160x90 64 colors: 14,400 bytes + 192 palette bytes, 4x scale 640x360'
Write-Host 'NO FLASH/NO FPGA PROGRAMMING. Build only.'
Write-Host "Build log: $log"
$start=[DateTime]::UtcNow
Push-Location $project
try {
    & $GowinShell 'build_tp25k_compat199.tcl' 2>&1 | Tee-Object -FilePath $log
    $exitCode=$LASTEXITCODE
} finally {Pop-Location}
Write-Host "GOWIN EXIT: $exitCode"
if($exitCode -ne 0){throw "BUILD FAILED (Gowin exit $exitCode)"}
$fs=Join-Path $project 'impl\pnr\chipmusic_tp25k.fs'
if(!(Test-Path -LiteralPath $fs)){throw 'No FPGA .fs output'}
$fi=Get-Item -LiteralPath $fs
if($fi.Length -lt 100000 -or $fi.LastWriteTimeUtc -lt $start.AddSeconds(-5)){
    throw "Stale or undersized bitstream $fs"
}
$destination=Join-Path $art 'chipmusic_tp25k_PR25_14.fs'
Copy-Item -LiteralPath $fs -Destination $destination -Force
$sha=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant()
$report=Join-Path $project 'impl\pnr\chipmusic_tp25k_tr_content.html'
$setup=$null;$hold=$null;$recovery=@()
if(Test-Path -LiteralPath $report){
  $html=[IO.File]::ReadAllText($report)
  foreach($kind in @('Setup','Hold')){
    $found=[regex]::Match($html,'(?is)<td[^>]*>\s*Numbers of '+$kind+' Violated Endpoints\s*</td>\s*<td[^>]*>\s*(\d+)\s*</td>')
    if($found.Success){
      if($kind -eq 'Setup'){$setup=[int]$found.Groups[1].Value}
      else{$hold=[int]$found.Groups[1].Value}
    }
  }
}
@{
 status='BUILD_PASS_STA_REVIEW_REQUIRED';timestamp=(Get-Date).ToString('o')
 upstream_commit=$m.source_commit;based_on='PR25-13 verified VIDEO+AUDIO baseline'
 source_root=$project;bitstream=$destination;bitstream_size=$fi.Length
 bitstream_sha256=$sha;rom_sha256=$shaRaw
 global_setup_violations=$setup;global_hold_violations=$hold
 gowin_exit=$exitCode;sta_report=$report;build_log=$log;board='NOT_TESTED'
}|ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $art 'PR25_14_manifest.json') -Encoding utf8
Write-Host "BUILD PASS: $destination"
Write-Host "SHA256: $sha"
Write-Host "GLOBAL SETUP VIOLATIONS: $setup"
Write-Host "GLOBAL HOLD VIOLATIONS: $hold"
Write-Host 'DO NOT PROGRAM without reviewing all timing warnings first.'
