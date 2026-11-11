# Safe LAB-04 verification: source/model and optional Icarus UART tap simulation.
# No Gowin build, no serial port, no FPGA programming and no source modification.
param([switch]$ModelOnly)
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent $PSScriptRoot
$root = Split-Path -Parent $lab
& python (Join-Path $lab 'tools\build_rom.py') --check
if ($LASTEXITCODE -ne 0) { throw 'LAB04 ROM build check failed' }
& python (Join-Path $lab 'tests\test_lab04_model.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 pure-Python firmware model failed' }
& python (Join-Path $lab 'tests\test_lab04_sources.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 source/constraint contracts failed' }
& python (Join-Path $lab 'tests\test_lab04_sta_reset_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 reset-domain source contracts failed' }
& python (Join-Path $lab 'tests\test_lab04_serdes_lane_reset_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 per-lane reset source contracts failed' }
& python (Join-Path $lab 'tests\test_sta_cdc_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 SVO CDC constraints contract failed' }
& python (Join-Path $lab 'tests\test_lab04_v016_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 v0.1.6 integration contract failed' }
& python (Join-Path $lab 'tests\test_lab04_sta_v016a_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 inherited v0.1.6a CDC SDC contract failed' }
& python (Join-Path $lab 'tests\test_lab04_v017_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB04.3 v0.1.7 MMIO/graphics contract failed' }
& python (Join-Path $lab 'tests\test_lab0432_contract.py')
if ($LASTEXITCODE -ne 0) { throw 'LAB0432 source/MEM contracts failed' }
& python (Join-Path $lab 'tools\console_lab04.py') --dry-run
if ($LASTEXITCODE -ne 0) { throw 'LAB04 console mapping failed' }
if ($ModelOnly) {
    Write-Host 'LAB0432_MODEL_PASS: interactive shell firmware and source contracts; RTL/STA/board not tested'
    return
}
foreach ($exe in @('iverilog','vvp')) {
    if (-not (Get-Command $exe -ErrorAction SilentlyContinue)) {
        throw "$exe missing from PATH; rerun -ModelOnly for pure Python checks"
    }
}
$build = Join-Path $lab 'build\uart_simulation'
New-Item -ItemType Directory -Force -Path $build | Out-Null
$vvp = Join-Path $build 'tb_uart_bridge.vvp'
& iverilog -g2012 -Wall -s tb_lab04_uart_tty_bridge -o $vvp `
    (Join-Path $root 'rtl\uart_rx_8n1.v') `
    (Join-Path $lab 'rtl\lab04_uart_tty_bridge.v') `
    (Join-Path $lab 'tests\tb_lab04_uart_tty_bridge.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 UART tap RTL compilation failed' }
& vvp $vvp
if ($LASTEXITCODE -ne 0) { throw 'LAB04 UART tap RTL simulation failed' }

# New v0.1.6 RTL checks. Each executable is isolated under ignored build/.
$vvpCDC = Join-Path $build 'tb_led_cdc.vvp'
& iverilog -g2012 -Wall -s tb_lab04_led_mask_cdc -o $vvpCDC `
    (Join-Path $lab 'rtl\lab04_led_mask_cdc.v') `
    (Join-Path $lab 'tests\tb_lab04_led_mask_cdc.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 CDC RTL compilation failed' }
& vvp $vvpCDC
if ($LASTEXITCODE -ne 0) { throw 'LAB04 CDC RTL simulation failed' }

$vvpOSD = Join-Path $build 'tb_led_osd.vvp'
& iverilog -g2012 -Wall -s tb_lab04_led_osd -o $vvpOSD `
    (Join-Path $lab 'rtl\lab04_led_osd.v') `
    (Join-Path $lab 'tests\tb_lab04_led_osd.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 OSD RTL compilation failed' }
& vvp $vvpOSD
if ($LASTEXITCODE -ne 0) { throw 'LAB04 OSD RTL simulation failed' }
# New v0.1.7 asynchronous video command mailbox and frame-commit graphics.
$vvpVideo = Join-Path $build 'tb_video_cmd_cdc.vvp'
& iverilog -g2012 -Wall -s tb_lab04_video_cmd_cdc -o $vvpVideo `
    (Join-Path $lab 'rtl\lab04_video_cmd_cdc.v') `
    (Join-Path $lab 'tests\tb_lab04_video_cmd_cdc.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 video command mailbox RTL compile failed' }
& vvp $vvpVideo
if ($LASTEXITCODE -ne 0) { throw 'LAB04 video command mailbox RTL simulation failed' }
$vvpGfx = Join-Path $build 'tb_graphics_osd.vvp'
& iverilog -g2012 -Wall -s tb_lab04_graphics_osd -o $vvpGfx `
    (Join-Path $lab 'rtl\lab04_graphics_osd.v') `
    (Join-Path $lab 'tests\tb_lab04_graphics_osd.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 graphics OSD RTL compile failed' }
& vvp $vvpGfx
if ($LASTEXITCODE -ne 0) { throw 'LAB04 graphics OSD RTL simulation failed' }
Write-Host 'LAB0432_LEGACY_VIDEO_RTL_PASS: UART, LED OSD, video mailbox and graphics; PnR/STA/board PENDING.'
# Addressable v0.1.8b TTY CDC and pixel-console tests, with no vendor models.
$vvpTty = Join-Path $build 'tb_tty_byte_cdc.vvp'
& iverilog -g2012 -Wall -s tb_lab04_tty_byte_cdc -o $vvpTty `
    (Join-Path $lab 'rtl\lab04_tty_byte_cdc.v') `
    (Join-Path $lab 'tests\tb_lab04_tty_byte_cdc.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 v018b byte CDC RTL compile failed' }
& vvp $vvpTty
if ($LASTEXITCODE -ne 0) { throw 'LAB04 v018b byte CDC RTL simulation failed' }
$vvpConsole = Join-Path $build 'tb_pikosol_console.vvp'
& iverilog -g2012 -Wall -s tb_lab04_console_osd -o $vvpConsole `
    (Join-Path $lab 'rtl\lab04_tty_byte_cdc.v') `
    (Join-Path $lab 'rtl\lab04_console_osd.v') `
    (Join-Path $lab 'tests\tb_lab04_console_osd.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB04 v018b console RTL compile failed' }
# $readmemh uses the simulator working directory (not the RTL source path).
# Run just the font-console simulation from rtl/, then always restore cwd.
Push-Location (Join-Path $lab 'rtl')
try {
    & vvp $vvpConsole
    if ($LASTEXITCODE -ne 0) { throw 'LAB04 v018b1 console RTL simulation failed' }
} finally { Pop-Location }
Write-Host 'LAB0432_MODEL_AND_RTL_PASS: shell model, 32x76 terminal, graphics and byte CDC. Gowin/STA/BOARD PENDING.'



# LAB-04.3.2 real PicoRV32 + BRAM command execution (vendor CPU, no Gowin IP).
$vvpSOC = Join-Path $build 'tb_lab0432_soc.vvp'
& iverilog -g2012 -Wall -s tb_lab0432_soc -o $vvpSOC `
    (Join-Path $root 'vendor\picorv32\picorv32.v') `
    (Join-Path $root 'rtl\uart_tx_8n1.v') `
    (Join-Path $root 'rtl\uart_rx_8n1.v') `
    (Join-Path $lab 'rtl\lab04_boot_rom.v') `
    (Join-Path $lab 'rtl\lab04_cpu_soc.v') `
    (Join-Path $lab 'tests\tb_lab0432_soc.v')
if ($LASTEXITCODE -ne 0) { throw 'LAB0432 real PicoRV32 RTL compile failed' }
# The SoC $readmemh in lab04_boot_rom.v loads the generated firmware ROM.
# Keep the console font simulation above in rtl/, but run the SoC test
# in firmware/ so lab04_boot.hex is found without writing to source dirs.
$romHex = Join-Path $lab 'firmware\lab04_boot.hex'
if (-not (Test-Path -LiteralPath $romHex -PathType Leaf)) {
    throw "LAB0432 ROM HEX missing: $romHex"
}
Push-Location (Join-Path $lab 'firmware')
try {
    & vvp $vvpSOC
    if ($LASTEXITCODE -ne 0) { throw 'LAB0432 real PicoRV32 UART/RAM RTL simulation failed' }
} finally { Pop-Location }
Write-Host 'LAB0432_RTL_ACCEPTANCE_PASS: all model, CDC, console and PicoRV32 integration tests passed; PnR/STA/board PENDING.'
