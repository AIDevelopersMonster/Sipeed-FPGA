# SD-06B offline ONLY. No Gowin programming, COM, or card writes.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $here '..\..\..\..')).Path
$spi = Join-Path $repo 'boards\tang-nano-9k\experiments\sd-mbr-fat32\rtl\spi_byte.v'
$core = Join-Path $here 'rtl\sd06_cmd24_engine.v'
$tb = Join-Path $here 'tests\tb_sd06_cmd24.v'
foreach ($path in @($spi, $core, $tb)) {
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
