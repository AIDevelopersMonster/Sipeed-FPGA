#requires -Version 7.0
<# LAB-06: activate an EXISTING MSYS2 UCRT64 install for current PowerShell.
   This script does NOT install packages, run a build, or access the FPGA. #>
[CmdletBinding()]
param([string]$MSYS2Root = '')
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'Windows PowerShell 7 required' }
$roots = if ([string]::IsNullOrWhiteSpace($MSYS2Root)) {
    @('C:\msys64', 'D:\msys64', 'C:\tools\msys64')
} else { @($MSYS2Root) }
$root = $null
foreach ($candidate in $roots) {
    if (Test-Path -LiteralPath (Join-Path $candidate 'usr\bin\pacman.exe') -PathType Leaf) {
        $root = $candidate
        break
    }
}
if ($null -eq $root) { throw 'MSYS2 not found; supply -MSYS2Root with its installation folder' }
$ucrt = Join-Path $root 'ucrt64\bin'
$usr = Join-Path $root 'usr\bin'
if (-not (Test-Path -LiteralPath $ucrt -PathType Container)) { throw 'UCRT64 bin directory is missing' }
$entries = @($ucrt, $usr) + @($env:PATH -split ';' | Where-Object { $_ })
$env:PATH = ($entries | Select-Object -Unique) -join ';'
Write-Host ('LAB06_MSYS2_PATH_ACTIVE: ' + $root) -ForegroundColor Green
$missing = @()
foreach ($name in @('ghdl','riscv64-unknown-elf-gcc','make','gcc')) {
    $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        Write-Host ('LAB06_TOOL_MISSING: ' + $name) -ForegroundColor Yellow
        $missing += $name
    } else {
        Write-Host ('LAB06_TOOL_FOUND: ' + $name + ' = ' + $cmd.Source) -ForegroundColor Green
    }
}
if ($missing.Count -eq 0) {
    Write-Host 'LAB06_UCRT64_TOOLCHAIN_READY' -ForegroundColor Green
} else {
    Write-Host 'LAB06_UCRT64_TOOLCHAIN_INCOMPLETE: see 02-NEORV32/README.md' -ForegroundColor Yellow
}
Write-Host 'LAB06_NO_FPGA_ACCESS: no simulation or programming has been attempted.'
