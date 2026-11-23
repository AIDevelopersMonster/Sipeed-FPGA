#requires -Version 7.0
# LAB-00 local RTL simulation only. Never touches a board.
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$iv = Get-Command iverilog -ErrorAction SilentlyContinue
$vp = Get-Command vvp -ErrorAction SilentlyContinue
if (-not $iv -or -not $vp) {
    throw 'Icarus Verilog missing. Install iverilog and vvp and add both to PATH.'
}
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('TN9K_LAB00_SIM_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    $output = Join-Path $work 'lab00_tb.vvp'
    $rtl = Join-Path $PSScriptRoot 'rtl\lab00_led_top.v'
    $tb = Join-Path $PSScriptRoot 'tb\lab00_led_tb.v'
    & $iv.Source -g2012 -s lab00_led_tb -o $output $rtl $tb
    if ($LASTEXITCODE -ne 0) { throw "Icarus compilation failed: $LASTEXITCODE" }
    $result = & $vp.Source $output 2>&1
    $text = ($result | Out-String)
    Write-Host $text
    if ($LASTEXITCODE -ne 0 -or $text -notmatch 'LAB00_RTL_SIM_PASS') {
        throw 'LAB00_RTL_SIM_FAIL'
    }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
