#Requires -Version 7.0
<#
PR25-HDMI-AUDIO-BRAM-01 - experiment ONLY.
One self-contained Windows PowerShell entrypoint:
  1) mandatory content simulation (Icarus)
  2) fetch PINNED upstream thisiseth HDL/PLL (sparse Git clone)
  3) build Gowin bitstream for the user's actual GW5A-LV25MG121NC1/I0
  4) optionally write ONLY FPGA SRAM, never Flash, after JTAG check and consent
No GitHub pushes, releases or changes to C:\GitHub\Sipeed-FPGA.
The resulting image is NOT hardware-proven until operator confirms picture + stereo.
#>
[CmdletBinding()]
param(
    [switch] $SimOnly,
    [switch] $ProgramSRAM,
    [ValidateRange(0,3)][int] $CableIndex = 1,
    [string] $Gowin = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe',
    [string] $Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe',
    [string] $Iverilog = 'C:\msys64\ucrt64\bin\iverilog.exe',
    [string] $Vvp = 'C:\msys64\ucrt64\bin\vvp.exe'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $PSCommandPath
$work = Join-Path $env:TEMP 'PR25_HDMI_AUDIO_BRAM_01'
$upstream = Join-Path $work 'upstream'
$build = Join-Path $work 'build'
$evidence = Join-Path $work 'evidence'
$upstreamURL = 'https://github.com/thisiseth/tang-primer-25k-spi-io.git'
$upstreamCommit = 'cce99075f06d0946c8a70c221118df2c4b57fe2a'
$base = 'pr25_hdmi_audio_bram'
$start = Get-Date -Format 'yyyyMMdd_HHmmss'
New-Item -ItemType Directory -Force -Path $work, $build, $evidence | Out-Null

function Need-File([string]$path) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Required file not found: $path"
    }
}
function Check-Exit([string]$step) {
    if ($LASTEXITCODE -ne 0) { throw "$step failed with exit code $LASTEXITCODE" }
}
function ToTclPath([string]$path) {
    $p = [IO.Path]::GetFullPath($path).Replace('\','/')
    if ($p.Contains('{') -or $p.Contains('}')) { throw "Unsupported braces in path: $p" }
    return '{' + $p + '}'
}

$tb = Join-Path $here 'tb_pr25_av_content.sv'
$content = Join-Path $here 'pr25_av_content.sv'
$top = Join-Path $here 'pr25_hdmi_audio_top.sv'
$cst = Join-Path $here 'pr25_hdmi_audio.cst'
$sdc = Join-Path $here 'pr25_hdmi_audio.sdc'
foreach($p in @($tb,$content,$top,$cst,$sdc,$Iverilog,$Vvp)) { Need-File $p }

# Safety checks on the local board-specific inputs before running any tool.
$cstText = Get-Content -LiteralPath $cst -Raw
foreach($pin in @('H5,J5','H8,H7','G7,G8','F5,G5','E2')) {
    if (-not $cstText.Contains($pin)) { throw "PINMAP CHECK FAILED: missing $pin" }
}
if ($cstText -match 'IO_LOC\s+".*"\s+(G11|D11|B11|C11);') {
    throw 'PINMAP CHECK FAILED: HDMI pins conflict with SPI / TF pins'
}
Write-Host 'TARGET: Tang Primer 25K Dock, GW5A-LV25MG121NC1/I0' -ForegroundColor Cyan
Write-Host 'DVI PMOD: keep it in the SAME SOCKET as working A2600Nano Golden'
Write-Host 'HDMI pins: CLK H5/J5; D0 H8/H7; D1 G7/G8; D2 F5/G5'
Write-Host 'NO SDRAM, NO BL616, NO USB, NO TF card; NO FLASH / NO GitHub writes.'

# Simulation: independent of PLL and Gowin, verifies pattern and left/right PCM.
$simExe = Join-Path $work 'av_content_sim.vvp'
Write-Host '=== 1. Icarus content simulation ==='
& $Iverilog '-g2012' '-s' 'tb_pr25_av_content' '-o' $simExe $tb $content
Check-Exit 'IVERILOG_COMPILE'
& $Vvp $simExe
Check-Exit 'AV_CONTENT_SIM'
Write-Host 'SIM PASS: RGB bars and both audio sample channels' -ForegroundColor Green
if($SimOnly) { return }

Need-File $Gowin
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git CLI not found. Install Git for Windows or use an existing installation.' }

# Fetch sources from original author at an immutable commit.
Write-Host '=== 2. Fetch pinned upstream HDMI and PLL sources ==='
if (-not (Test-Path -LiteralPath (Join-Path $upstream '.git'))) {
    & git clone --quiet --depth 1 --filter=blob:none --sparse $upstreamURL $upstream
    Check-Exit 'GIT_CLONE'
}
& git -C $upstream sparse-checkout set src/fpga/spi_io_bridge/src/hdmi src/fpga/spi_io_bridge/src/gowin
Check-Exit 'GIT_SPARSE_CHECKOUT'
$actualCommit = (& git -C $upstream rev-parse HEAD | Out-String).Trim()
Check-Exit 'GIT_REV_PARSE'
if ($actualCommit -ne $upstreamCommit) {
    throw "Upstream HEAD changed, refusing unpinned source: $actualCommit expected $upstreamCommit. No FPGA write."
}
$dirty = (& git -C $upstream status --porcelain | Out-String).Trim()
Check-Exit 'GIT_STATUS'
if ($dirty.Length -ne 0) { throw "Upstream sparse checkout modified, refusing: $dirty" }

$remoteSrc = Join-Path $upstream 'src\fpga\spi_io_bridge\src'
$pll = Join-Path $remoteSrc 'gowin\pll_hdmi_720.v'
Need-File $pll
$hdmiFiles = @(
  'audio_clock_regeneration_packet.sv',
  'audio_info_frame.sv',
  'audio_sample_packet.sv',
  'auxiliary_video_information_info_frame.sv',
  'hdmi.sv',
  'packet_assembler.sv',
  'packet_picker.sv',
  'serializer.sv',
  'source_product_description_info_frame.sv',
  'tmds_channel.sv'
)
$srcPaths = [System.Collections.Generic.List[string]]::new()
$srcPaths.Add($pll)
foreach($f in $hdmiFiles) {
    $p = Join-Path $remoteSrc "hdmi\$f"
    Need-File $p
    $srcPaths.Add($p)
}
# Use a Gowin-only OSER10 adapter rather than relying on the upstream's
# platform-dependent macro ordering (SYNTHESIS/GW_IDE branches).
# The adapter reproduces the three OSER10 instances from upstream's GW_IDE path.
$serialSource = Join-Path $remoteSrc 'hdmi\serializer.sv'
$serialAdapter = Join-Path $here 'pr25_serializer_gowin.sv'
Need-File $serialAdapter
$serialText = Get-Content -LiteralPath $serialSource -Raw
if ($serialText -notmatch 'OSER10' -or $serialText -notmatch 'tmds_clock = clk_pixel') {
    throw 'Upstream reference serializer architecture changed; refusing unreviewed sources.'
}
$srcPaths.Remove($serialSource) | Out-Null
$srcPaths.Add($serialAdapter)
$srcPaths.Add($content)
$srcPaths.Add($top)
$srcPaths.Add($cst)
$srcPaths.Add($sdc)
Write-Host "SOURCE PINNED: thisiseth/$upstreamCommit"
Write-Host 'BOARD INPUTS VERIFIED: GW5A 25A, 50MHz E2, original Golden HDMI differential pairs.'

# Generate TCL in an isolated build folder. Do not touch user's Github clone.
$tclFile = Join-Path $build 'build_pr25_hdmi_audio.tcl'
$tcl = [System.Collections.Generic.List[string]]::new()
$tcl.Add('set_device GW5A-LV25MG121NC1/I0 -name GW5A-25A')
foreach($p in $srcPaths) { $tcl.Add('add_file ' + (ToTclPath $p)) }
$tcl.Add('set_option -synthesis_tool gowinsynthesis')
$tcl.Add('set_option -output_base_name ' + $base)
$tcl.Add('set_option -verilog_std sysv2017')
$tcl.Add('set_option -top_module pr25_hdmi_audio_top')
# GW5A-25A: E2 is multiplexed with dedicated CPU/SSPI functionality.
# Golden A2600Nano build_tp25k.tcl uses the same option.
$tcl.Add('set_option -use_cpu_as_gpio 1')
$tcl.Add('set_option -bit_compress 1')
$tcl.Add('set_option -user_code 00000001')
$tcl.Add('run all')
[IO.File]::WriteAllLines($tclFile, $tcl, [Text.UTF8Encoding]::new($false))

# The Gowin toolchain was not available to the package author.
# Only your own Gowin build output is allowed to establish BUILD PASS.
$log = Join-Path $evidence "GOWIN_BUILD_$start.log"
$buildStarted = [DateTime]::UtcNow
Write-Host '=== 3. Gowin GW5A-25A synthesis, P&R and bitstream generation ==='
Push-Location $build
try {
    & $Gowin (Split-Path -Leaf $tclFile) 2>&1 | Tee-Object -FilePath $log
    $buildExit = $LASTEXITCODE
} finally {
    Pop-Location
}
if ($buildExit -ne 0) {
    Write-Host 'BUILD LOG tail:'
    Get-Content -LiteralPath $log -Tail 45
    throw "GOWIN_BUILD_FAIL code=$buildExit log=$log"
}
$bits = @(
    Get-ChildItem -LiteralPath $build -Recurse -File -Filter "$base.fs" -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTimeUtc -ge $buildStarted.AddSeconds(-5) -and $_.Length -gt 200000 }
)
if($bits.Count -ne 1) {
    throw "BUILD FAIL: fresh $base.fs not found exactly once; count=$($bits.Count). Log=$log"
}
$fs = $bits[0].FullName
$sha = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host 'CLI BUILD PASS: new bitstream generated (NOT a hardware PASS).' -ForegroundColor Green
Write-Host "FS: $fs"
Write-Host "BYTES: $($bits[0].Length)"
Write-Host "SHA256: $sha"
Write-Host "GOWIN BUILD LOG: $log"
Write-Host 'IMPORTANT: timing closure (including PLL/OSER10 recovery) must be checked in Gowin timing reports.' -ForegroundColor Yellow

if (-not $ProgramSRAM) {
    Write-Host 'STOP: no FPGA write requested. Use -ProgramSRAM only after reviewing build/timing reports.'
    return
}

Need-File $Programmer
Write-Host '=== 4. JTAG scan and explicit volatile SRAM programming ==='
$scanLog = Join-Path $evidence "JTAG_SCAN_$start.log"
$scan = (& $Programmer --scan --cable-index $CableIndex 2>&1 | Tee-Object -FilePath $scanLog | Out-String)
Check-Exit 'JTAG_SCAN'
Write-Host $scan
if ($scan -notmatch 'GW5A-25A') {
    throw "Wrong device or JTAG output: GW5A-25A not found in scan. Refusing to write. Log=$scanLog"
}
Write-Warning 'ABOUT TO REPLACE ONLY THE CURRENT VOLATILE SRAM FPGA CONFIGURATION.'
Write-Warning 'No Flash write is requested; the bitstream is an UNTESTED candidate.'
$confirmation = Read-Host 'Type exactly SRAM to authorize this temporary test'
if ($confirmation -cne 'SRAM') { throw 'CANCELLED: no FPGA programming performed.' }
$programLog = Join-Path $evidence "SRAM_PROGRAM_$start.log"
& $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs 2>&1 | Tee-Object -FilePath $programLog
Check-Exit 'SRAM_PROGRAM'
Write-Host 'SRAM PROGRAM COMMAND PASS, BOARD STILL UNKNOWN.' -ForegroundColor Yellow
Write-Host 'Expected picture: red, green, blue, white vertical bars (with black horizontal line near bottom).'
Write-Host 'Expected audio: LEFT approximately 500Hz, RIGHT approximately 750Hz, low volume.'
Write-Host "PROGRAM LOG: $programLog"
Write-Host "ALL OUTPUTS: $work"
