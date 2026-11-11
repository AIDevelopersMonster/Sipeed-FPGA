# The only entry point for LAB-02 verification. Never programs flash or SRAM.
param([switch]$ModelOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    & python tools/assemble.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 assembler failed.' }
    & python tools/test_lab02_firmware.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 model test failed.' }
    if ($ModelOnly) {
        Write-Host 'LAB02 MODEL_PASS only. UART RTL, CPU RTL and FPGA NOT TESTED.'
        return
    }
    foreach ($tool in @('iverilog','vvp')) {
        if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
            throw "Missing $tool. Run -ModelOnly for limited firmware check."
        }
    }
    New-Item -ItemType Directory -Force -Path build | Out-Null
    & iverilog -g2012 -s tb_uart_rx -o build/lab02_uart_rx.vvp rtl/uart_rx_8n1.v tests/tb_uart_rx.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 RX RTL compile failed.' }
    & vvp build/lab02_uart_rx.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 RX RTL simulation failed.' }
    & iverilog -g2012 -s tb_uart -o build/lab02_uart_tx.vvp rtl/uart_tx_8n1.v tests/tb_uart.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 TX RTL compile failed.' }
    & vvp build/lab02_uart_tx.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 TX RTL simulation failed.' }
    $vendor = 'vendor/picorv32/picorv32.v'
    if (-not (Test-Path $vendor)) {
        throw 'Original PicoRV32 RTL absent. Run tools/fetch_picorv32.ps1 (pinned upstream source).'
    }
    & iverilog -g2012 -s tb_uart_console -o build/lab02_soc.vvp `
       $vendor rtl/boot_rom.v rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v rtl/picorv32_soc.v `
       tests/tb_uart_console.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 SoC RTL compile failed.' }
    & vvp build/lab02_soc.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB02 SoC RTL simulation failed.' }
    Write-Host 'LAB02 MODEL_PASS + RTL_PASS. Gowin PnR and BOARD NOT TESTED.'
} finally { Pop-Location }
