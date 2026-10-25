# SD-05 local offline gates. No FPGA programming and no SD card writes.
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
& python -m unittest discover -s (Join-Path $here 'tests') -p 'test_*.py' -v
if ($LASTEXITCODE -ne 0) {throw 'SD05 Python FAIL'}
$exp=Split-Path -Parent $here
$sd03=Join-Path $exp 'sd-mbr-fat32'
$work=Join-Path ([System.IO.Path]::GetTempPath()) ("sd05-"+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $work | Out-Null
try {
    $deps=@(
      (Join-Path $sd03 'rtl/spi_byte.v'),
      (Join-Path $sd03 'rtl/sd_read_sector.v'),
      (Join-Path $sd03 'rtl/uart_tx_8n1.v'),
      (Join-Path $here 'rtl/uart_rx_8n1.v'),
      (Join-Path $here 'rtl/sd05_lba_bridge_top.v')
    )
    & iverilog -g2005 -s sd05_lba_bridge_top -o (Join-Path $work 'top.vvp') @deps
    if ($LASTEXITCODE -ne 0) {throw 'SD05 RTL compile FAIL'}
    # The TB defines a MOCK lab05_sd_read_sector; do not include the real
    # sd_read_sector.v here. The real production core is compiled above.
    $simDeps = @(
      (Join-Path $sd03 'rtl/uart_tx_8n1.v'),
      (Join-Path $here 'rtl/uart_rx_8n1.v'),
      (Join-Path $here 'rtl/sd05_lba_bridge_top.v'),
      (Join-Path $here 'tests/tb_sd05_uart_bridge.v')
    )
    & iverilog -g2005 -s tb_sd05_uart_bridge -o (Join-Path $work 'uart_tb.vvp') @simDeps
    if ($LASTEXITCODE -ne 0) {throw 'SD05 UART bridge testbench compile FAIL'}
    $sim = & vvp (Join-Path $work 'uart_tb.vvp') 2>&1
    $simrc = $LASTEXITCODE
    $sim | ForEach-Object {Write-Host $_}
    if ($simrc -ne 0 -or -not ($sim -match 'SD05_UART_BRIDGE_TB_PASS')) {
        throw 'SD05 UART bridge integration simulation FAIL'
    }
    Write-Host 'SD05_OFFLINE_GATE_PASS: Python + RTL + UART end-to-end simulation'
} finally {Remove-Item -LiteralPath $work -Force -Recurse -ErrorAction SilentlyContinue}
