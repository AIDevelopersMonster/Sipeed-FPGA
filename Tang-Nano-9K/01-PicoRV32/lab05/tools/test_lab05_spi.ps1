# LAB-05.1 standalone model only, no programmer and no baseline modification.
$ErrorActionPreference = 'Stop'
$lab = Split-Path -Parent $PSScriptRoot
$exe = Get-Command iverilog -ErrorAction Stop
$vvp = Get-Command vvp -ErrorAction Stop
$dst = Join-Path ([System.IO.Path]::GetTempPath()) ("lab05_spi_" + [guid]::NewGuid().ToString('N') + ".vvp")
try {
    & $exe.Source -g2012 -s tb_lab05_spi_byte -o $dst (Join-Path $lab 'rtl\lab05_spi_byte.v') (Join-Path $lab 'tests\tb_lab05_spi_byte.v')
    if ($LASTEXITCODE -ne 0) { throw 'Icarus compilation failed' }
    & $vvp.Source $dst
    if ($LASTEXITCODE -ne 0) { throw 'Icarus simulation failed' }
} finally {
    Remove-Item -LiteralPath $dst -Force -ErrorAction SilentlyContinue
}
