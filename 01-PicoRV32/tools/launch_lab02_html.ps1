# Start a local loopback HTTP server for Web Serial secure context.
# Press Ctrl+C to stop. This script does not touch the FPGA or COM port.
param([ValidateSet('RU','EN')][string]$Language='RU',[int]$Port=8765)
$ErrorActionPreference='Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$htmlDir = Join-Path $repo 'docs\interactive\picorv32-led1\linked'
$file = "PicoRV32_LED1_Linked_$Language.html"
if (-not (Test-Path -LiteralPath (Join-Path $htmlDir $file))) {
    throw "LAB-02 browser link not installed: $htmlDir\$file"
}
Write-Host "Open in Chrome or Edge: http://127.0.0.1:$Port/$file"
Write-Host "Use the built-in USB UART COM port (previously COM10). Close all other serial terminals."
Write-Host "Press Ctrl+C here to stop the local server."
& python -m http.server $Port --bind 127.0.0.1 --directory $htmlDir
