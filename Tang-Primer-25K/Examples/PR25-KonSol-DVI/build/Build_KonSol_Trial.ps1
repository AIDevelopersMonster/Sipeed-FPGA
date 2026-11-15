#Requires -Version 7.0
# PR25-KonSol LOCAL TRIAL, no GitHub writes, no Flash writes.
# One and only RTL substitution: original lab_top.sv -> local lab_top_konsol.sv.
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
$expectedSourceCommit = '817bd4dac8ab45d5c22bdd78b441bedb80672cd0'
$expectedOriginalFsSha = '7aab221d20f8851ff8e0689437975df193461c1a0847e532a9f11644eee904ef'
$vendor = Join-Path $PanchulRoot '_vendor\basics-graphics-music'
$originalTcl = Join-Path $PanchulRoot 'work\build_panchul_hdmi.tcl'
$originalFs = Join-Path $PanchulRoot 'work\impl\pnr\pr25_panchul_hdmi.fs'
$originalLab = Join-Path $vendor 'labs\2_graphics\2_3_color_stripes\lab_top.sv'
$trialLab = Join-Path $PSScriptRoot 'lab_top_konsol.sv'
$trialDir = Join-Path $env:TEMP 'PR25_KonSol_LocalTrial'
$trialTcl = Join-Path $trialDir 'build_konsol_trial.tcl'
$trialFs = Join-Path $trialDir 'impl\pnr\pr25_konsol_trial.fs'

foreach ($path in @($vendor,$originalTcl,$originalFs,$originalLab,$trialLab,$GowinShell)) {
    if (!(Test-Path -LiteralPath $path)) { throw "Required path missing: $path" }
}
if (!(Get-Command git -ErrorAction SilentlyContinue)) { throw 'git command unavailable' }
$commit = (& git -C $vendor rev-parse HEAD | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or $commit -ne $expectedSourceCommit) {
    throw "Upstream source commit mismatch: expected $expectedSourceCommit, actual $commit"
}
$modified = @(& git -C $vendor status --porcelain --untracked-files=no)
if ($LASTEXITCODE -ne 0 -or $modified.Count -gt 0) { throw 'Original upstream tracked files are modified; aborting' }
$originalSha = (Get-FileHash -LiteralPath $originalFs -Algorithm SHA256).Hash.ToLowerInvariant()
if ($originalSha -ne $expectedOriginalFsSha) {
    throw "Original working Panchul bitstream SHA256 mismatch: $originalSha"
}

# All generated outputs go under TEMP, outside the user Git worktrees.
New-Item -ItemType Directory -Force -Path $trialDir | Out-Null
# We clean ONLY the previous generated build directory for this isolated trial.
$oldImpl = Join-Path $trialDir 'impl'
if (Test-Path -LiteralPath $oldImpl) { Remove-Item -LiteralPath $oldImpl -Recurse -Force }

function GowinPath([string]$path) {
    $value = [IO.Path]::GetFullPath($path).Replace('\','/')
    if ($value.Contains('{') -or $value.Contains('}')) { throw 'Unsupported braces in path' }
    return ('{' + $value + '}')
}

# Reuse the already PROVEN project source list, original device, PLL, IP and CST.
# Only replace the one lab source entry and the output bitstream base name.
$tcl = [IO.File]::ReadAllText($originalTcl)
$before = 'add_file -type verilog ' + (GowinPath $originalLab)
$after  = 'add_file -type verilog ' + (GowinPath $trialLab)
if ([regex]::Matches($tcl,[regex]::Escape($before)).Count -ne 1) {
    throw 'Original TCL does not contain exactly one expected lab_top source entry'
}
$tcl = $tcl.Replace($before, $after)
$oldBase = 'set_option -output_base_name pr25_panchul_hdmi'
$newBase = 'set_option -output_base_name pr25_konsol_trial'
if ([regex]::Matches($tcl,[regex]::Escape($oldBase)).Count -ne 1) {
    throw 'Original TCL unexpected output_base_name; refusing unsafe modification'
}
$tcl = $tcl.Replace($oldBase, $newBase)
# Because only the one HDL add_file line and one output name differ, the
# Gowin vendor DVI IP, clocking, pin assignments and timing remain original.
[IO.File]::WriteAllText($trialTcl, $tcl, [Text.UTF8Encoding]::new($false))
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $trialDir ("build_konsol_$stamp.log")
$startUtc = [DateTime]::UtcNow
Write-Host 'PR25-KonSol: static 80x30 color commander screen, 640x480 DVI'
Write-Host 'DVI PMOD: keep exactly where operator confirmed working (under USB-A).'
Write-Host 'Only substituted RTL: lab_top_konsol.sv'
Write-Host 'Original CST, PLL, DVI_TX, VGA: UNCHANGED'
Write-Host "Local temporary work: $trialDir"
Write-Host "RTL SHA256: $((Get-FileHash $trialLab -Algorithm SHA256).Hash)"
Write-Host "LOG: $log"

$exitCode = -1
Push-Location $trialDir
try {
    & $GowinShell 'build_konsol_trial.tcl' 2>&1 | Tee-Object -FilePath $log
    $exitCode = $LASTEXITCODE
} finally { Pop-Location }
if ($exitCode -ne 0) { throw "CLI BUILD FAIL ($exitCode); see $log" }
if (!(Test-Path -LiteralPath $trialFs)) { throw "Gowin exited successfully, but no FS was generated: $trialFs" }
$item = Get-Item -LiteralPath $trialFs
if ($item.Length -lt 100000 -or $item.LastWriteTimeUtc -lt $startUtc.AddSeconds(-5)) {
    throw 'Generated FS stale or unexpectedly small'
}
$sha = (Get-FileHash -LiteralPath $trialFs -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "CLI BUILD PASS: $trialFs"
Write-Host "FS size: $($item.Length) bytes"
Write-Host "SHA256: $sha"
Write-Host 'STA: requires separate review. BOARD VIDEO: NOT YET VERIFIED.'
$trFiles = @(Get-ChildItem -LiteralPath (Join-Path $trialDir 'impl') -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match 'tr_content\.html$|_tr\.html$' })
foreach ($tr in $trFiles) { Write-Host "TIMING REPORT: $($tr.FullName)" }

if ($ProgramSRAM) {
    if (!(Test-Path -LiteralPath $Programmer)) { throw "Programmer CLI missing: $Programmer" }
    Write-Host 'PROGRAMMING ONLY VOLATILE SRAM (--run 2). NO FLASH OPERATIONS.'
    & $Programmer --device GW5A-25A --cable-index $CableIndex --run 2 --fsFile $trialFs
    $programExit = $LASTEXITCODE
    Write-Host "SRAM PROGRAM EXIT: $programExit"
    if ($programExit -ne 0) { throw 'SRAM programming failed' }
    Write-Host 'Observe KonSol-style color 80x30 screen. Physical BOARD PASS requires operator confirmation.'
} else {
    Write-Host 'FPGA was NOT programmed. To SRAM-program after reviewing build/STA:'
    Write-Host ('& "' + $Programmer + '" --device GW5A-25A --cable-index ' + $CableIndex + ' --run 2 --fsFile "' + $trialFs + '"')
}
Write-Host "Original Panchul FS preserved: $originalFs"
Write-Host 'Nothing saved to GitHub; all experimental build files are in TEMP.'
