#Requires -Version 7.0
# PR25-HDMI-PANCHUL-01: pin upstream source, generate TCL, synthesize original
# board/lab RTL with Gowin. NO SRAM/Flash/JTAG programming in this script.
[CmdletBinding()]
param(
    [string]$GowinShell = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe',
    [switch]$PrepareOnly
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$expected = '817bd4dac8ab45d5c22bdd78b441bedb80672cd0'
$upstreamUrl = 'https://github.com/yuri-panchul/basics-graphics-music.git'
$upstream = Join-Path $PSScriptRoot '_vendor\basics-graphics-music'
$work = Join-Path $PSScriptRoot 'work'
$evidence = Join-Path $PSScriptRoot 'evidence'
$manifestPath = Join-Path $work 'manifest.json'
$tclPath = Join-Path $work 'build_panchul_hdmi.tcl'
$labRel = 'labs/2_graphics/2_3_color_stripes'
$boardRel = 'boards/tang_primer_25k_pmod_hdmi'
$board = Join-Path $upstream $boardRel
$lab = Join-Path $upstream $labRel
$pixelClock = '125 MHz DVI serializer / 25 MHz RGB; 640x480'
$projectName = 'pr25_panchul_hdmi'
New-Item -ItemType Directory -Force -Path (Split-Path $upstream -Parent),$work,$evidence | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $evidence ("PR25_PANCHUL_BUILD_$stamp.log")

if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git CLI is not installed' }
if (!(Test-Path -LiteralPath (Join-Path $upstream '.git'))) {
    if (Test-Path -LiteralPath $upstream) {
        throw "A non-Git directory exists at $upstream; refusing overwrite"
    }
    & git clone --depth 1 --filter=blob:none --sparse $upstreamUrl $upstream
    if ($LASTEXITCODE -ne 0) { throw 'Failed to clone original Panchul repository' }
}
$head = (& git -C $upstream rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0) { throw 'Cannot read cached source commit' }
if ($head -ne $expected) {
    & git -C $upstream fetch --depth 1 origin $expected
    if ($LASTEXITCODE -ne 0) { throw 'Cannot fetch pinned source commit' }
    & git -C $upstream checkout --detach $expected
    if ($LASTEXITCODE -ne 0) { throw 'Cannot checkout pinned source commit' }
}
$selectedDirectories = @(
    'boards/tang_primer_25k_pmod_hdmi',
    'boards/tang_primer_25k_pmod_vga',
    'peripherals',
    'labs/common',
    $labRel
)
& git -C $upstream sparse-checkout set -- @selectedDirectories
if ($LASTEXITCODE -ne 0) { throw 'Sparse checkout of original modules failed' }
$actual = (& git -C $upstream rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $actual -ne $expected) {
    throw "Source mismatch: expected $expected, actual $actual"
}
$dirty = @(& git -C $upstream status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $dirty.Count -gt 0) {
    throw 'Original tracked files have local edits; refusing to build'
}

# Use the ORIGINAL upstream board wrapper and color-stripe lab. The include
# inside board_specific_top.sv resolves the unchanged VGA/DVI shared wrapper.
$fixed = @(
    "$boardRel/board_specific_top.sv",
    "$boardRel/dvi_tx.v",
    "$boardRel/gowin_pll/gowin_pll.v",
    "$labRel/lab_top.sv"
)
$files = [System.Collections.Generic.List[string]]::new()
foreach ($rel in $fixed) {
    $full = Join-Path $upstream $rel
    if (!(Test-Path -LiteralPath $full)) { throw "Missing pinned source: $rel" }
    $files.Add($full)
}
foreach ($directory in @('peripherals','labs/common')) {
    $path = Join-Path $upstream $directory
    $extra = Get-ChildItem -LiteralPath $path -File |
        Where-Object { $_.Extension -in @('.v','.sv') -and $_.Name -notmatch '^tb(?:_|[.])' } |
        Sort-Object Name
    foreach ($f in $extra) { $files.Add($f.FullName) }
}
# Avoid duplicate generated dvi_tx.v revisions from the nested vendor IP
# directory; use ONLY the original, canonical root-level dvi_tx.v (unchanged).
function TclPath([string]$value) {
    $normalized = [IO.Path]::GetFullPath($value).Replace('\','/')
    if ($normalized.Contains('{') -or $normalized.Contains('}')) {
        throw "Braces in path are not supported: $normalized"
    }
    return ('{' + $normalized + '}')
}
$tcl = [System.Collections.Generic.List[string]]::new()
$tcl.Add('# PR25-HDMI-PANCHUL-01: script-generated from unchanged upstream sources')
$tcl.Add("# Source commit $expected")
$tcl.Add('set_device GW5A-LV25MG121NC1/I0 -device_version A')
$tcl.Add('set_option -synthesis_tool gowinsynthesis')
$tcl.Add("set_option -output_base_name $projectName")
$tcl.Add('set_option -top_module board_specific_top')
$tcl.Add('set_option -verilog_std sysv2017')
$tcl.Add('set_option -use_cpu_as_gpio 1')
$tcl.Add('set_option -use_i2c_as_gpio 1')
foreach ($directory in @($boardRel,$labRel,'peripherals','labs/common')) {
    $tcl.Add('set_option -include_path ' + (TclPath (Join-Path $upstream $directory)))
}
foreach ($file in $files) { $tcl.Add('add_file -type verilog ' + (TclPath $file)) }
$tcl.Add('add_file -type cst ' + (TclPath (Join-Path $board 'board_specific.cst')))
$tcl.Add('add_file -type sdc ' + (TclPath (Join-Path $board 'board_specific.sdc')))
$tcl.Add('run all')
$tcl | Set-Content -LiteralPath $tclPath -Encoding utf8

# PREPARE PASS is never a BUILD PASS. Invalidate previous PASS for every run.
$manifest = [ordered]@{
    id = 'PR25-HDMI-PANCHUL-01'
    status = 'PREPARE_PASS_BUILD_NOT_RUN'
    upstream = $upstreamUrl
    source_commit = $expected
    board = 'Tang Primer 25K / GW5A-LV25MG121NC1-I0'
    configuration = $boardRel
    lab = $labRel
    output = $pixelClock
    original_rtl_modified = $false
    extra_pmod_devices_required_by_lab = 'TM1638 and I2S are referenced by the original lab wrapper; absent hardware has not been qualified'
    tcl_file = $tclPath
    source_count = $files.Count
    tcl_sha256 = (Get-FileHash -LiteralPath $tclPath -Algorithm SHA256).Hash
    build_log = $null
    bitstream = $null
    sha256 = $null
    timing = 'NOT_REVIEWED'
    board_video = 'NOT_TESTED'
    board_audio = 'NOT_APPLICABLE_DVI_ONLY'
    utc = (Get-Date).ToUniversalTime().ToString('o')
}
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "PREPARE PASS: pinned Panchul source $actual"
Write-Host "Original source files: $($files.Count)"
Write-Host "Gowin TCL: $tclPath"
if ($PrepareOnly) {
    Write-Host 'PREPARE ONLY: no synthesis, no FPGA programming'
    return
}
if (!(Test-Path -LiteralPath $GowinShell)) {
    throw "Gowin CLI not found: $GowinShell; prepared source/TCL remain available"
}

$started = [DateTime]::UtcNow
$exitCode = -1
Push-Location $work
try {
    & $GowinShell 'build_panchul_hdmi.tcl' 2>&1 | Tee-Object -FilePath $log
    $exitCode = $LASTEXITCODE
} finally { Pop-Location }

$manifest.build_log = $log
$manifest.utc = (Get-Date).ToUniversalTime().ToString('o')
if ($exitCode -ne 0) {
    $manifest.status = 'BUILD_FAIL'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    throw "Gowin BUILD FAIL ($exitCode). Log: $log"
}

$fs = Join-Path $work ("impl\pnr\$projectName.fs")
if (!(Test-Path -LiteralPath $fs)) {
    $manifest.status = 'BUILD_FAIL_NO_FS'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    throw "Gowin exited 0 but created no FS: $fs"
}
$item = Get-Item -LiteralPath $fs
if ($item.Length -lt 100000 -or $item.LastWriteTimeUtc -lt $started.AddSeconds(-5)) {
    $manifest.status = 'BUILD_FAIL_STALE_OR_SMALL_FS'
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
    throw "FS too small or stale: $fs"
}
$manifest.status = 'CLI_BUILD_PASS_STA_REVIEW_REQUIRED_BOARD_NOT_TESTED'
$manifest.bitstream = $fs
$manifest.sha256 = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash.ToLowerInvariant()
$manifest.size = $item.Length
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "CLI BUILD PASS: $fs"
Write-Host "SHA256: $($manifest.sha256)"
Write-Host "LOG: $log"
Write-Host "TIMING: NOT REVIEWED; BOARD: NOT TESTED; NO FPGA WRITES PERFORMED"
