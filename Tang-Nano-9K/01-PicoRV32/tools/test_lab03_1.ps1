# LAB-03.1: RTL recorder + real LAB-02 SoC passive-trace test.
# Read-only with respect to tracked sources; no FPGA programming, no COM.
param([switch]$UnitOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
foreach ($tool in @('iverilog','vvp')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "Missing $tool. Install Icarus Verilog; no RTL test has been run."
    }
}
Push-Location $root
try {
    New-Item -ItemType Directory -Force -Path build | Out-Null
    & iverilog -g2012 -Wall -s tb_lab03_trace_capture -o build/lab03_trace_unit.vvp `
        rtl/lab03_trace_capture.v tests/tb_lab03_trace_capture.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB03.1 capture RTL compile failed' }
    & vvp build/lab03_trace_unit.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB03.1 capture RTL run failed' }

    if ($UnitOnly) {
        Write-Host 'LAB03_1_UNIT_RTL_PASS ONLY; full SoC, PnR and BOARD NOT TESTED.'
        return
    }
    $core = 'vendor/picorv32/picorv32.v'
    if (-not (Test-Path $core)) {
        throw 'Pinned PicoRV32 missing. Run .\01-PicoRV32\tools\fetch_picorv32.ps1 from repo root.'
    }
    # Regenerates only the existing LAB-02 ROM and HEX from boot.S.
    & python tools/assemble.py
    if ($LASTEXITCODE -ne 0) { throw 'LAB-02 firmware assembly failed' }
    & iverilog -g2012 -Wall -s tb_lab03_soc_trace -o build/lab03_trace_soc.vvp `
        $core rtl/boot_rom.v rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v `
        rtl/picorv32_soc.v rtl/lab03_trace_capture.v tests/tb_lab03_soc_trace.v
    if ($LASTEXITCODE -ne 0) { throw 'LAB03.1 real SoC trace RTL compile failed' }
    & vvp build/lab03_trace_soc.vvp
    if ($LASTEXITCODE -ne 0) { throw 'LAB03.1 real SoC trace RTL run failed' }
    Write-Host 'LAB03_1_RTL_PASS: recorder and real PicoRV32-SoC trace. FPGA PnR/BOARD NOT TESTED.'
} finally { Pop-Location }
