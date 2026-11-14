# PR25-09: one-command HDMI audio diagnostic launcher.
# -Program explicitly enables FPGA SRAM programming. NEVER programs Flash.
[CmdletBinding()]
param(
    [switch]$Program,
    [int]$CableIndex = 1
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$root = $PSScriptRoot
$build = Join-Path $root 'Build_HDMI_AUDIO.ps1'
$loader = Join-Path $root 'Program_SRAM.ps1'
$fs = Join-Path $root 'impl\pnr\pr25_hdmi_audio_diag.fs'
$golden = Join-Path $root '..\PR25-08-HDMI-AUDIO-GOLDEN\impl\pnr\pr25_hdmi_audio.fs'
$evidence = Join-Path $root 'evidence'
New-Item -Path $evidence -ItemType Directory -Force | Out-Null
$log = Join-Path $evidence ('PR25_09_RUN_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
Start-Transcript -Path $log -ErrorAction Stop | Out-Null
try {
    Write-Host 'PR25-09 HDMI AUDIO DIAGNOSTIC'
    Write-Host 'Target: Tang Primer 25K GW5A-25A; PMOD DVI USB-A side'
    Write-Host 'Build: GW5A-25A, audio diagnostic. NO FLASH PROGRAMMING.'
    Write-Host "Evidence: $log"
    if (Test-Path -LiteralPath $golden) {
        Write-Host 'PR25-08 GOLDEN VIDEO PASS bitstream remains available:'
        Write-Host "  $golden"
        Write-Host "  SHA256: $((Get-FileHash -LiteralPath $golden -Algorithm SHA256).Hash)"
    } else {
        Write-Host 'NOTE: original PR25-08 bitstream not found locally; source remains in GitHub.'
    }
    & $build
    if (!(Test-Path -LiteralPath $fs)) {
        throw "PR25-09 bitstream missing: $fs"
    }
    $item = Get-Item -LiteralPath $fs
    $hash = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
    Write-Host 'PR25-09 BUILD OUTPUT:'
    Write-Host "  FS: $($item.FullName)"
    Write-Host "  BYTES: $($item.Length)"
    Write-Host "  SHA256: $hash"
    Write-Host 'IMPORTANT: review Gowin timing setup/hold report; BUILD PASS alone is not STA PASS.'
    if (-not $Program) {
        Write-Host 'BUILD ONLY. FPGA SRAM not changed. Use -Program to load when timing is acceptable.'
    } else {
        Write-Host "Programming GW5A-25A, cable $CableIndex in SRAM; external Flash untouched."
        & $loader -CableIndex $CableIndex
        Write-Host 'PROGRAM COMMAND COMPLETE (NOT AUDIO BOARD PASS).'
        Write-Host 'Observe: color bars; top-left marker green 0.75s / red 0.25s; HDMI ~1kHz stereo beep.'
        Write-Host 'Set monitor volume low initially: the test square wave is comparatively loud.'
        Write-Host 'Report THREE items: image yes/no; marker changes yes/no; sound yes/no.'
    }
}
finally {
    Stop-Transcript | Out-Null
    Write-Host "Saved operator transcript: $log"
}
