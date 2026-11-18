#requires -Version 7.0
<#
.SYNOPSIS
    Read-only JTAG detection for Sipeed Tang Primer 20K / Gowin GW2A.
.DESCRIPTION
    Calls only Gowin Programmer CLI --scan-cables and --scan.
    Does NOT program SRAM, NOR Flash or any FPGA configuration memory.
    Writes a local diagnostic log under TEMP; do not publish raw logs
    without inspecting and removing local identifiers.
.EXAMPLE
    .\tp20-jtag-scan.ps1 -ProgrammerCli "C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe"
#>
[CmdletBinding()]
param(
    [string]$ProgrammerCli = "",
    [string]$LogDirectory = (Join-Path $env:TEMP "TP20-JTAG")
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ProgrammerCli)) {
    $found = Get-Command -Name "programmer_cli.exe" -ErrorAction SilentlyContinue
    if ($null -eq $found) {
        throw "Pass -ProgrammerCli with the path to programmer_cli.exe (or add it to PATH)."
    }
    $ProgrammerCli = $found.Source
}

if (-not (Test-Path -LiteralPath $ProgrammerCli -PathType Leaf)) {
    throw "Gowin Programmer CLI not found: $ProgrammerCli"
}

New-Item -ItemType Directory -Path $LogDirectory -Force | Out-Null
$logFile = Join-Path $LogDirectory ("TP20_JTAG_{0}.txt" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

"=== TANG PRIMER 20K READ-ONLY JTAG SCAN ===" | Tee-Object -FilePath $logFile
"=== --scan-cables ===" | Tee-Object -FilePath $logFile -Append
& $ProgrammerCli --scan-cables 2>&1 | Tee-Object -FilePath $logFile -Append
$cableExit = $LASTEXITCODE
if ($cableExit -ne 0) {
    throw "Cable scan failed with exit code $cableExit. Local log: $logFile"
}

"=== --scan ===" | Tee-Object -FilePath $logFile -Append
& $ProgrammerCli --scan 2>&1 | Tee-Object -FilePath $logFile -Append
$scanExit = $LASTEXITCODE
if ($scanExit -ne 0) {
    throw "JTAG scan failed with exit code $scanExit. Local log: $logFile"
}

$result = Get-Content -LiteralPath $logFile -Raw
if (($result -notmatch '(?m)^\s*Family:\s*GW2A\s*$') -or
    ($result -notmatch '(?m)^\s*ID:\s*0x[0-9a-fA-F]+\s*$') -or
    ($result -notmatch '(?m)^\s*1 device\(s\) found!')) {
    Write-Warning "Scan completed, but the expected single GW2A device was not confirmed. Review log."
} else {
    Write-Host "JTAG SCAN PASS: one GW2A family device found (read-only)."
}

Write-Host "Local log: $logFile"
Write-Host "Do not publish raw local logs without redacting machine identifiers."
