#Requires -Version 7.0
# PR25 TETRIS-HID-06 -- proven HID05 USB low/full-speed + own FPGA game.
# Actively drives USB-A D+/D- according to USB protocol, NOT a passive GPIO probe.
# No GitHub writes, no Flash, no UART dependency. Only local trial SRAM.
[CmdletBinding()]
param(
    [string]$PanchulRoot = 'C:\GitHub\PR25-HDMI-PANCHUL-01\Tang-Primer-25K\Examples\PR25-HDMI-PANCHUL-01',
    [string]$GowinShell = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\IDE\bin\gw_sh.exe',
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe',
    [int]$CableIndex = 1,
    [switch]$ProgramSRAM
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$sourceCommit = '817bd4dac8ab45d5c22bdd78b441bedb80672cd0'
$repositoryUrl = 'https://github.com/yuri-panchul/basics-graphics-music.git'
$sourceBase = 'boards/tang_primer_25k_pmod_hdmi'
$sourceLab = 'labs/2_graphics/2_3_color_stripes'
$work = Join-Path $env:TEMP 'PR25_TETRIS_HID_06'
$trialLab = Join-Path $PSScriptRoot 'lab_top_tetris_hid06.sv'
$tclPath = Join-Path $work 'build_tetris_hid06.tcl'
$fs = Join-Path $work 'impl\pnr\pr25_tetris_hid06.fs'
$log = Join-Path $work 'build_tetris_hid06.log'

if (!(Test-Path -LiteralPath $trialLab -PathType Leaf)) { throw "RTL not found: $trialLab" }
if (!(Test-Path -LiteralPath $GowinShell -PathType Leaf)) { throw "gw_sh.exe not found: $GowinShell" }
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git CLI is not available' }
New-Item -ItemType Directory -Path $work -Force | Out-Null

# Prefer the already tested upstream checkout, but NEVER modify a user's checkout.
$localVendor = Join-Path $PanchulRoot '_vendor\basics-graphics-music'
$vendor = $null
if (Test-Path -LiteralPath (Join-Path $localVendor '.git')) {
    $localCommit = (& git -C $localVendor rev-parse HEAD | Out-String).Trim()
    $localChanges = @(& git -C $localVendor status --porcelain --untracked-files=no)
    if ($LASTEXITCODE -eq 0 -and $localCommit -eq $sourceCommit -and $localChanges.Count -eq 0) {
        $vendor = $localVendor
        Write-Host "Using clean local source: $vendor"
    }
}
if ($null -eq $vendor) {
    $vendor = Join-Path $work '_vendor\basics-graphics-music'
    if (!(Test-Path -LiteralPath (Join-Path $vendor '.git'))) {
        if (Test-Path -LiteralPath $vendor) { throw "Non-Git vendor directory exists: $vendor" }
        New-Item -ItemType Directory -Force -Path (Split-Path $vendor -Parent) | Out-Null
        & git clone --depth 1 --filter=blob:none --sparse $repositoryUrl $vendor
        if ($LASTEXITCODE -ne 0) { throw 'Unable to clone pinned DVI source' }
    }
    $current = (& git -C $vendor rev-parse HEAD | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read DVI source commit' }
    if ($current -ne $sourceCommit) {
        & git -C $vendor fetch --depth 1 origin $sourceCommit
        if ($LASTEXITCODE -ne 0) { throw 'Unable to fetch pinned DVI source revision' }
        & git -C $vendor checkout --detach $sourceCommit
        if ($LASTEXITCODE -ne 0) { throw 'Unable to check out pinned DVI source revision' }
    }
    $sparse = @($sourceBase, 'boards/tang_primer_25k_pmod_vga', 'peripherals', 'labs/common', $sourceLab)
    & git -C $vendor sparse-checkout set -- @sparse
    if ($LASTEXITCODE -ne 0) { throw 'Sparse checkout failed' }
    Write-Host "Using isolated pinned source: $vendor"
}
$actual = (& git -C $vendor rev-parse HEAD | Out-String).Trim()
$dirty = @(& git -C $vendor status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $actual -ne $sourceCommit -or $dirty.Count -gt 0) {
    throw "DVI source dirty or wrong commit: $actual"
}

$board = Join-Path $vendor $sourceBase
$originalCst = Join-Path $board 'board_specific.cst'
$originalSdc = Join-Path $board 'board_specific.sdc'
$originalLab = Join-Path $vendor "$sourceLab/lab_top.sv"
foreach ($p in @($originalCst, $originalSdc, $originalLab)) {
    if (!(Test-Path -LiteralPath $p)) { throw "Missing pinned DVI project source: $p" }
}
$ipConfig = Join-Path $board 'dvi_tx\dvi_tx.ipc'
$ipV = Join-Path $board 'dvi_tx\dvi_tx.v'
if (!(Test-Path -LiteralPath $ipV) -or !(Test-Path -LiteralPath $ipConfig)) {
    throw 'The correct nested protected DVI_TX_Top IP is missing'
}
$ip = [IO.File]::ReadAllLines($ipConfig)
foreach ($setting in @('module=DVI_TX_Top', 'ELVDS=true', 'USING_EXTERNAL_CLOCK=true')) {
    if ($ip -notcontains $setting) { throw "Unexpected DVI_TX variant, missing $setting" }
}

# USB pin map matches physical-probe BOARD PASS: 30=D+, 31=D-.
# USB core now actively drives these pins only in HOST mode. DVI pins remain identical.
$oldCst = [IO.File]::ReadAllText($originalCst)
$pinPattern = '(?m)^[ \t]*IO_LOC[ \t]+"GPIO\[30\]"[ \t]+J10[ \t]*;[ \t]*IO_LOC[ \t]+"GPIO\[31\]"[ \t]+J11[ \t]*;?[ \t]*\r?$'
if ([regex]::Matches($oldCst, $pinPattern).Count -ne 1) {
    throw 'CST has an unexpected GPIO[30]/GPIO[31] arrangement; no patch applied'
}
if ([regex]::IsMatch($oldCst, '(?m)^[ \t]*IO_LOC\s+"[^\"]+"[^\r\n]*\b(?:L6|K6)\b')) {
    throw 'USB pins L6/K6 already mapped in original CST: refusing pin collision'
}
$newPin = 'IO_LOC "GPIO[30]" L6;' + [Environment]::NewLine + 'IO_LOC "GPIO[31]" K6;'
$newCst = [regex]::Replace($oldCst, $pinPattern, $newPin)
$newCst += [Environment]::NewLine + 'IO_PORT "GPIO[30]" IO_TYPE=LVCMOS33 PULL_MODE=NONE DRIVE=8 BANK_VCCIO=3.3;'
$newCst += [Environment]::NewLine + 'IO_PORT "GPIO[31]" IO_TYPE=LVCMOS33 PULL_MODE=NONE DRIVE=8 BANK_VCCIO=3.3;'
$newCst += [Environment]::NewLine
$trialCst = Join-Path $work 'pr25_usb_hid_dvi.cst'
[IO.File]::WriteAllText($trialCst, $newCst, [Text.UTF8Encoding]::new($false))

function TclPath([string]$path) {
    $v = [IO.Path]::GetFullPath($path).Replace('\','/')
    if ($v.Contains('{') -or $v.Contains('}')) { throw "Unsupported brackets in path: $path" }
    return '{' + $v + '}'
}

# Retain proven DVI wrapper/source order. New RTL includes LS+FS USB HID host.
$inputs = [System.Collections.Generic.List[string]]::new()
foreach ($rel in @(
    "$sourceBase/board_specific_top.sv",
    "$sourceBase/dvi_tx/dvi_tx.v",
    "$sourceBase/gowin_pll/gowin_pll.v"
)) { $inputs.Add((Join-Path $vendor $rel)) }
$inputs.Add($trialLab)
$tetrisEngine = Join-Path $PSScriptRoot 'tetris_engine.sv'
if (!(Test-Path -LiteralPath $tetrisEngine -PathType Leaf)) { throw "Game engine missing: $tetrisEngine" }
$inputs.Add($tetrisEngine)

# m1nl (Apache-2.0), rewrite of nand2mario, supports Full Speed and Low Speed.
# All blobs are pinned to an immutable commit. The clock PLL is a separately
# pinned vendor-generated source from the old 12-MHz project, edited in a
# LOCAL GENERATED COPY to produce 60 MHz; original is never overwritten.
$hidCommit = '5d2bf72472bddc6da71134fa7d29d42a99a02f0a'
$hidBase = "https://raw.githubusercontent.com/m1nl/usb_hid_host/$hidCommit"
$hidVendor = Join-Path $work 'hid_upstream'
New-Item -ItemType Directory -Force $hidVendor | Out-Null

function Get-GitBlobSha([string]$path) {
    $b = [IO.File]::ReadAllBytes($path)
    $header = [Text.Encoding]::ASCII.GetBytes("blob $($b.Length)`0")
    $all = [byte[]]::new($header.Length + $b.Length)
    [Buffer]::BlockCopy($header,0,$all,0,$header.Length)
    [Buffer]::BlockCopy($b,0,$all,$header.Length,$b.Length)
    return [Convert]::ToHexString([Security.Cryptography.SHA1]::HashData($all)).ToLowerInvariant()
}
function PinnedFetch([string]$url,[string]$fileName,[string]$blobSha) {
    $dst = Join-Path $hidVendor $fileName
    if (!(Test-Path -LiteralPath $dst -PathType Leaf) -or (Get-GitBlobSha $dst) -ne $blobSha) {
        Invoke-WebRequest -Uri $url -OutFile $dst
    }
    if ((Get-GitBlobSha $dst) -ne $blobSha) {
        throw "PINNED SOURCE HASH MISMATCH: $url"
    }
    Write-Host "PINNED SOURCE PASS: $fileName"
    return $dst
}
$srcHid = PinnedFetch "$hidBase/rtl/usb_hid_host.v" 'usb_hid_host.v' '1b2b9b280ccd3b2d6d3424819b4bc6c0a887b8f1'
$srcRom = PinnedFetch "$hidBase/rtl/usb_hid_host_rom.v" 'usb_hid_host_rom.v' '31f4525f98b5508e0cee0c72b045f25b5110f2bd'
$srcHex = PinnedFetch "$hidBase/rom/usb_hid_host_rom.mem" 'usb_hid_host_rom.mem' 'a3df44e5aa54f71a3a2d009f4e1afb393b05ed92'
$pllOriginalCommit = '678b0137bd32d1ca99fb2d48865f4eb1df712c4e'
$pllOriginalUrl = "https://raw.githubusercontent.com/nand2mario/usb_hid_host/$pllOriginalCommit/boards/tang-nano20k-primer25k/primer25k/gowin_pll_usb.v"
$srcPll12 = PinnedFetch $pllOriginalUrl 'gowin_pll_usb_12mhz_original.v' 'eadfe2e62773a89a87c7ea401e432f616a772dc4'

# PLLA on GW5A: original 50*18/75 = 12MHz. Change only ODIV0=15 -> 60MHz.
# This change requires a fresh Gowin BUILD and timing review; do not claim STA PASS.
$pllOrig = [IO.File]::ReadAllText($srcPll12)
$beforeDiv = 'defparam PLLA_inst.ODIV0_SEL = 75;'
$afterDiv  = 'defparam PLLA_inst.ODIV0_SEL = 15;'
if ([regex]::Matches($pllOrig,[regex]::Escape($beforeDiv)).Count -ne 1) {
    throw 'Unexpected GOWIN PLL configuration; refusing blind clock patch'
}
$srcPll60 = Join-Path $work 'gowin_pll_usb_60mhz.v'
[IO.File]::WriteAllText($srcPll60, $pllOrig.Replace($beforeDiv,$afterDiv), [Text.UTF8Encoding]::new($false))
# ROM path is relative to Gowin working directory. Keep the exact pinned file.
Copy-Item -LiteralPath $srcHex -Destination (Join-Path $work 'usb_hid_host_rom.mem') -Force
$inputs.Add($srcHid)
$inputs.Add($srcRom)
$inputs.Add($srcPll60)

foreach ($rel in @('peripherals','labs/common')) {
    $folder = Join-Path $vendor $rel
    $extras = @(Get-ChildItem -LiteralPath $folder -File |
      Where-Object { $_.Extension -in @('.v','.sv') -and $_.Name -notmatch '^tb(?:_|[.])' } |
      Sort-Object Name)
    foreach ($f in $extras) { $inputs.Add($f.FullName) }
}
foreach ($f in $inputs) { if (!(Test-Path -LiteralPath $f)) { throw "HDL input missing: $f" } }
$cmds = [System.Collections.Generic.List[string]]::new()
$cmds.Add('# PR25_TETRIS_HID_06 LS+FS HID trial, SRAM only')
$cmds.Add("# DVI source pinned: $sourceCommit")
$cmds.Add('set_device GW5A-LV25MG121NC1/I0 -device_version A')
$cmds.Add('set_option -synthesis_tool gowinsynthesis')
$cmds.Add('set_option -output_base_name pr25_tetris_hid06')
$cmds.Add('set_option -top_module board_specific_top')
$cmds.Add('set_option -verilog_std sysv2017')
$cmds.Add('set_option -use_cpu_as_gpio 1')
$cmds.Add('set_option -use_i2c_as_gpio 1')
foreach ($dir in @($sourceBase,$sourceLab,'peripherals','labs/common')) {
    $cmds.Add('set_option -include_path ' + (TclPath (Join-Path $vendor $dir)))
}
foreach ($f in $inputs) { $cmds.Add('add_file -type verilog ' + (TclPath $f)) }
$cmds.Add('add_file -type cst ' + (TclPath $trialCst))
$cmds.Add('add_file -type sdc ' + (TclPath $originalSdc))
$cmds.Add('run all')
[IO.File]::WriteAllLines($tclPath, $cmds, [Text.UTF8Encoding]::new($false))

# Prevent stale .fs from being mistaken for fresh BUILD PASS.
$oldImpl = Join-Path $work 'impl'
if (Test-Path -LiteralPath $oldImpl) { Remove-Item -LiteralPath $oldImpl -Recurse -Force }
$startUtc = [DateTime]::UtcNow
Write-Host 'PR25-TETRIS-HID06: active LS+FS host on L6/K6, DVI untouched'
Write-Host 'DVI PMOD: DO NOT MOVE; original TMDS CST unchanged'
Write-Host 'NO FPGA FLASH WRITES, NO GITHUB WRITES'
Write-Host "RTL SHA256: $((Get-FileHash -LiteralPath $trialLab -Algorithm SHA256).Hash)"
Write-Host "TCL: $tclPath"
Write-Host "LOG: $log"
$exit = -1
Push-Location $work
try {
    & $GowinShell 'build_tetris_hid06.tcl' 2>&1 | Tee-Object -FilePath $log
    $exit = $LASTEXITCODE
} finally { Pop-Location }
if ($exit -ne 0) {
    Write-Host '---- LAST 65 LINES OF GOWIN LOG ----'
    Get-Content -LiteralPath $log -Tail 65 | ForEach-Object { Write-Host $_ }
    if ($exit -eq -1073741819) {
        Write-Warning 'Gowin crashed (Windows 0xC0000005 access violation) during tool execution.'
        Write-Warning 'This is a tool crash, not evidence that USB pins are bad. Keep this log for follow-up.'
    }
    throw "BUILD FAIL exit=$exit; log: $log"
}
if (!(Test-Path -LiteralPath $fs -PathType Leaf)) { throw "No bitstream produced: $fs" }
$item = Get-Item -LiteralPath $fs
if ($item.Length -lt 100000 -or $item.LastWriteTimeUtc -lt $startUtc.AddSeconds(-5)) {
    throw 'Bitstream stale or unexpectedly small; no BUILD PASS'
}
$sum = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "BUILD FILE PASS: $fs"
Write-Host "BYTES: $($item.Length)"
Write-Host "SHA256: $sum"
Write-Host 'STA: NOT REVIEWED; HID05 passed on board, new TETRIS06 NOT TESTED'
if ($ProgramSRAM) {
    if (!(Test-Path -LiteralPath $Programmer -PathType Leaf)) { throw "Programmer not found: $Programmer" }
    Write-Host 'PROGRAM SRAM ONLY (--run 2). No configuration Flash writes.'
    & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $fs
    $pExit = $LASTEXITCODE
    Write-Host "SRAM PROGRAM EXIT: $pExit"
    if ($pExit -ne 0) { throw "SRAM Program failed: $pExit" }
    Write-Host 'S1: PASSIVE -> GAME/HOST. F1: GAME <-> HID DIAG. USB hubs NOT supported.'
    Write-Host 'Controls: arrows or 1:left 2:rotate 3:right 4:drop 5:down; P pause; R restart.'
} else {
    Write-Host 'FPGA not programmed. Re-run with -ProgramSRAM to load volatile SRAM.'
}
