# PR25-05 UARTTX 9600: fetch, build, SRAM-only program, then receive COM25.
# This script does not write the FPGA SPI Flash or BL616 firmware.
param(
    [string]$Port = 'COM25',
    [int]$Seconds = 10
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$base = 'https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-05-UART-TX'
$dir = 'C:\GitHub'
New-Item -ItemType Directory -Force -Path $dir | Out-Null
foreach ($scriptName in @('Build_UARTTX.ps1','Program_SRAM_UARTTX.ps1','Probe_UARTTX.ps1')) {
    $dst = Join-Path $dir $scriptName
    Invoke-WebRequest -Uri "$base/$scriptName" -OutFile $dst
    if (!(Test-Path $dst) -or (Get-Item $dst).Length -eq 0) {
        throw "Download failed: $scriptName"
    }
}
Write-Host 'STEP 1: Build standalone 9600-baud FPGA UART'
& (Join-Path $dir 'Build_UARTTX.ps1')
Write-Host 'STEP 2: SRAM-only program; no flash writes'
& (Join-Path $dir 'Program_SRAM_UARTTX.ps1')
Write-Host 'STEP 3: Close any serial monitors holding COM25'
Write-Host "STEP 4: Capture $Port at 9600 8N1"
$log = Join-Path $dir ('UARTTX_9600_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
& (Join-Path $dir 'Probe_UARTTX.ps1') -Ports @($Port) -Bauds @(9600) -Seconds $Seconds |
    Tee-Object -FilePath $log
Write-Host "EVIDENCE LOG: $log"
