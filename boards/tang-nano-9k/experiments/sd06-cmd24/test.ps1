# SD-06B offline ONLY. No Gowin programming, COM, or card writes.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $here '..\..\..\..')).Path
$spi = Join-Path $repo 'boards\tang-nano-9k\experiments\sd-mbr-fat32\rtl\spi_byte.v'
$core = Join-Path $here 'rtl\sd06_cmd24_engine.v'
$tb = Join-Path $here 'tests\tb_sd06_cmd24.v'
$merged = Join-Path $here 'rtl\sd06_rw_bridge_top.v'
$reader = Join-Path $repo 'boards\tang-nano-9k\experiments\sd-mbr-fat32\rtl\sd_read_sector.v'
$tx = Join-Path $repo 'boards\tang-nano-9k\experiments\sd-mbr-fat32\rtl\uart_tx_8n1.v'
$rx = Join-Path $repo 'boards\tang-nano-9k\experiments\sd05-lba-bridge\rtl\uart_rx_8n1.v'
foreach ($path in @($spi, $core, $tb, $merged, $reader, $tx, $rx)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "SD06_REQUIRED_SOURCE_MISSING: $path; run git pull --ff-only on feature/sd06-cmd24-offline"
    }
}
foreach ($tool in @('python','iverilog','vvp')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
        throw "SD06_REQUIRED_TOOL_MISSING: $tool"
    }
}
$dir = Join-Path ([System.IO.Path]::GetTempPath()) ('sd06_offline_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $dir | Out-Null
try {
    & python -m unittest discover -s (Join-Path $here 'tests') -p 'test_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'SD06 Python offline tests FAIL' }
    & iverilog -g2005 -s sd06_cmd24_engine -o (Join-Path $dir 'real_spi.vvp') $spi $core
    if ($LASTEXITCODE -ne 0) { throw 'SD06 production SPI interface compile FAIL' }
    Write-Host 'SD06: compiling integrated UART/CMD17/CMD24 top with -Wall'
    & iverilog -Wall -g2005 -s sd06_rw_bridge_top -o (Join-Path $dir 'sd06_rw_integrated.vvp') $spi $core $merged $reader $tx $rx
    if ($LASTEXITCODE -ne 0) { throw "SD06 merged UART reader/writer top compile FAIL (iverilog exit $LASTEXITCODE); compiler diagnostics above" }
    Write-Host 'SD06_RW_TOP_COMPILE_PASS: compile only, NOT integrated simulation'
    # Testbench deliberately supplies a byte-SPI mock with the same module name.
    # Never include the production SPI module in this second compilation.
    & iverilog -g2005 -s tb -o (Join-Path $dir 'mock.vvp') $core $tb
    if ($LASTEXITCODE -ne 0) { throw 'SD06 byte-SPI testbench compile FAIL' }
    $sim = @(& vvp (Join-Path $dir 'mock.vvp') 2>&1)
    $code = $LASTEXITCODE
    $sim | ForEach-Object { Write-Host $_ }
    if ($code -ne 0 -or -not ($sim -match 'SD06_CMD24_BYTE_MODEL_ALL_PASS')) {
        throw 'SD06 CMD24 mock-card simulation FAIL'
    }
    Write-Host 'SD06B_OFFLINE_GATE_PASS: Python + production SPI compile + CMD24 mock simulation'
} finally {
    Remove-Item -LiteralPath $dir -Force -Recurse -ErrorAction SilentlyContinue
}
