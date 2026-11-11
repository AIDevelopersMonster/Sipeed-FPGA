# RTL tests require Icarus Verilog (iverilog and vvp) and pinned vendor CPU.
param([switch]$PythonOnly)
$ErrorActionPreference='Stop'
$Here = Split-Path -Parent $PSScriptRoot
Push-Location $Here
try {
  & python tools/assemble.py
  if ($LASTEXITCODE -ne 0) { throw 'Assembly failed.' }
  & python tools/test_firmware.py
  if ($LASTEXITCODE -ne 0) { throw 'Firmware model test failed.' }
  if ($PythonOnly) { Write-Host 'Python-only checks passed. RTL simulation NOT RUN.'; exit 0 }
  foreach ($tool in @('iverilog', 'vvp')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
      throw "Missing $tool. Install Icarus Verilog or use -PythonOnly (does NOT test RTL)."
    }
  }
  $vendor = 'vendor/picorv32/picorv32.v'
  if (-not (Test-Path $vendor)) {
    throw 'PicoRV32 source missing. Run tools/fetch_picorv32.ps1.'
  }
  New-Item -ItemType Directory -Force -Path build | Out-Null
  & iverilog -g2012 -s tb_uart -o build/tb_uart.vvp rtl/uart_tx_8n1.v tests/tb_uart.v
  if ($LASTEXITCODE -ne 0) { throw 'UART simulation compile failed.' }
  & vvp build/tb_uart.vvp
  if ($LASTEXITCODE -ne 0) { throw 'UART simulation FAILED.' }
  & iverilog -g2012 -s tb_soc -o build/tb_soc.vvp $vendor rtl/boot_rom.v rtl/uart_tx_8n1.v rtl/picorv32_soc.v tests/tb_soc.v
  if ($LASTEXITCODE -ne 0) { throw 'SoC simulation compile failed.' }
  & vvp build/tb_soc.vvp
  if ($LASTEXITCODE -ne 0) { throw 'SoC simulation FAILED.' }
  Write-Host 'RTL simulation PASS (Icarus, virtual CPU). Physical FPGA not verified.'
} finally { Pop-Location }
