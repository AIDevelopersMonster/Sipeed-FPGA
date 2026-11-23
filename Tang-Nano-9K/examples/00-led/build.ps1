#requires -Version 7.0
# LAB-00: isolated Gowin synthesis/PnR; candidate output, NEVER programs FPGA.
[CmdletBinding()]
param(
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference = 'Stop'
$gw = Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if (-not (Test-Path -LiteralPath $gw -PathType Leaf)) {
    throw "Gowin CLI not found: $gw (supply -GowinRoot)"
}
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('TN9K_LAB00_BUILD_' + (Get-Date -Format 'yyyyMMdd_HHmmss_fff'))
if (Test-Path -LiteralPath $work) { throw "Refusing existing build directory: $work" }
foreach ($dir in @($work, (Join-Path $work 'rtl'), (Join-Path $work 'constraints'))) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'rtl\lab00_led_top.v') -Destination (Join-Path $work 'rtl\lab00_led_top.v')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'constraints\lab00_led.cst') -Destination (Join-Path $work 'constraints\lab00_led.cst')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'constraints\lab00_led.sdc') -Destination (Join-Path $work 'constraints\lab00_led.sdc')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'build.tcl') -Destination (Join-Path $work 'build.tcl')
$log = Join-Path $work 'gowin.log'
Push-Location $work
try {
    & $gw build.tcl *> $log
    if ($LASTEXITCODE -ne 0) { throw "Gowin failed (exit $LASTEXITCODE): $log" }
} finally {
    Pop-Location
}
$files = @(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'tang_nano9k_lab00_led.fs')
if ($files.Count -ne 1) {
    throw "Expected exactly one .fs, found $($files.Count). Inspect $log"
}
$fs = $files[0].FullName
$hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
Write-Host "LAB00_CANDIDATE=$fs"
Write-Host "LAB00_SHA256=$hash"
Write-Host "LAB00_BUILD_LOG=$log"
Write-Warning 'UNTESTED CANDIDATE. Review full PnR/STA, pins and clock; THEN use program_sram.ps1 explicitly.'
