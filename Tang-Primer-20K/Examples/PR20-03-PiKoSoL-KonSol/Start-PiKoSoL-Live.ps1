#requires -Version 7.0
<#
PiKoSoL TP20: primary LIVE keyboard launcher.
- No FPGA programming, no Flash, no PC> line buffered input.
- -Recover: invoke the EXISTING XMODEM monitor loader and, after it exits,
  switch to the exact board-tested LIVE keyboard client.
- Does not assume the loader can be bypassed at "Waiting for downloader ...".
Examples:
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\Start-PiKoSoL-Live.ps1
  pwsh -NoProfile -ExecutionPolicy Bypass -File .\Start-PiKoSoL-Live.ps1 -Recover
#>
[CmdletBinding()]
param(
    [switch]$Recover,
    [switch]$HDMIOnly,
    [string]$Port = 'COM10',
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$legacy = Join-Path $root 'TP20_PiKoSoL_Run.ps1'
$live = Join-Path $root 'PiKoSoL_TP20_LIVE_KEYBOARD.py'

if (!(Test-Path -LiteralPath $live -PathType Leaf)) {
    throw "LIVE CLIENT NOT FOUND: $live. Copy the BOARD PASS .py into this folder first."
}
& $Python -B $live --selftest
if ($LASTEXITCODE -ne 0) { throw "LIVE KEYBOARD SELFTEST FAILED ($LASTEXITCODE)" }

if ($Recover) {
    if (!(Test-Path -LiteralPath $legacy -PathType Leaf)) {
        throw "MONITOR LOADER NOT FOUND: $legacy"
    }
    Write-Host 'RECOVERY: the board is at Waiting for downloader. Loading monitor using the existing XMODEM client.' -ForegroundColor Yellow
    Write-Host 'The legacy recovery tool may display PC>. Exit it after PiKoSoL> appears; only then LIVE starts.' -ForegroundColor Yellow
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $legacy -Attach -Port $Port -Python $Python
    if ($LASTEXITCODE -ne 0) { throw "RECOVERY FAILED (exit $LASTEXITCODE); LIVE NOT STARTED" }
}
Write-Host 'LIVE UART keyboard: typing appears on HDMI BEFORE Enter; Esc exits PC client.' -ForegroundColor Green
$argsLive = @('-B',$live,'--port',$Port,'--baud','115200')
if ($HDMIOnly) { $argsLive += '--hdmi-only' }
& $Python @argsLive
if ($LASTEXITCODE -ne 0) { throw "LIVE KEYBOARD FAILED (exit $LASTEXITCODE)" }
