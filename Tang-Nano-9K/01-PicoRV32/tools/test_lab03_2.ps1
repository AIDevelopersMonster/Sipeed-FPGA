# LAB-03.2: tests new source/model, real SoC UART RTL, and parses UART captures.
# Does not touch boot.hex, boot_rom.v, COM, Flash or the physical FPGA.
param([switch]$ModelOnly)
$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSScriptRoot
Push-Location $base
try {
    & python tools/assemble_lab03.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 separate ROM assembly failed' }
    & python tools/test_lab03_2_protocol.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 T3 protocol validation failed' }
    & python tools/test_lab03_2_firmware.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 firmware model failed' }
    Write-Host 'LAB03_2_MODEL_PASS: firmware + decoder unit tests; no RTL/PnR/BOARD claim.'
    if ($ModelOnly) { return }
    foreach ($tool in @('iverilog','vvp')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Missing $tool; full RTL was not run." }
    }
    if (-not (Test-Path 'vendor/picorv32/picorv32.v')) {
        throw 'Pinned PicoRV32 missing. Run .\01-PicoRV32\tools\fetch_picorv32.ps1 from the repository root.'
    }
    New-Item -ItemType Directory -Force -Path build | Out-Null
    & iverilog -g2012 -Wall -s tb_lab03_2_uart -o build/lab03_2_uart.vvp `
        vendor/picorv32/picorv32.v rtl/lab03_boot_rom.v `
        rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v `
        rtl/lab03_trace_capture.v rtl/picorv32_soc_lab03.v tests/tb_lab03_2_uart.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 RTL compile failed' }
    & vvp build/lab03_2_uart.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB-03.2 RTL simulation failed' }
    & python tools/lab03_trace_decode.py build/lab03_2_trace_4.txt --expected-command 4 `
        --json-out build/lab03_2_trace_4.json
    if ($LASTEXITCODE -ne 0) { throw 'First UART trace decode failed' }
    & python tools/lab03_trace_decode.py build/lab03_2_trace_4_repeat.txt --expected-command 4
    if ($LASTEXITCODE -ne 0) { throw 'Repeated UART trace decode failed' }
    & python tools/lab03_trace_decode.py build/lab03_2_trace_1.txt --expected-command 1 `
        --json-out build/lab03_2_trace_1.json
    if ($LASTEXITCODE -ne 0) { throw 'Second UART trace decode failed' }
    $h1=(Get-FileHash 'build/lab03_2_trace_4.txt' -Algorithm SHA256).Hash
    $h2=(Get-FileHash 'build/lab03_2_trace_4_repeat.txt' -Algorithm SHA256).Hash
    if ($h1 -ne $h2) { throw 'Immutable trace changed between two UART readouts' }
    Write-Host 'LAB03_2_RTL_PASS: real PicoRV32 SoC, UART T3 readout, clear/re-arm and snapshot ROM validation.'
    Write-Host 'FPGA Gowin PnR/STA and physical BOARD tests are NOT DONE.'
} finally { Pop-Location }
