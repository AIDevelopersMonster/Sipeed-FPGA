# PicoRV32 Trace Observatory v1.1.0. Archive ISA + optional Web Serial; no FPGA programming.
# Never modifies FPGA SRAM, Flash or USB drivers.
param([int]$Port=8765, [switch]$NoBrowser, [switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
$LabRoot = Split-Path -Parent $PSScriptRoot
$RepoRoot = Split-Path -Parent $LabRoot
$Serve = Join-Path $RepoRoot 'docs\lab03\observatory\serve.py'
if (-not (Test-Path -LiteralPath $Serve)) { throw "Observatory not installed: $Serve" }
$Arguments = @($Serve)
if ($CheckOnly) {
    $Arguments += '--check-only'
} else {
    $Arguments += @('--port', [string]$Port)
    if ($NoBrowser) { $Arguments += '--no-browser' }
}
& python @Arguments
if ($LASTEXITCODE -ne 0) { throw "LAB03_OBSERVATORY_SERVE_FAIL: Python exit $LASTEXITCODE" }
