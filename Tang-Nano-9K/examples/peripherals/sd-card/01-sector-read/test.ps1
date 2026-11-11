# SDHC command/CRC simulation with card model. No hardware, no CPU.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$lab=Join-Path $repo '01-PicoRV32\lab05'
$iverilog=(Get-Command iverilog -ErrorAction Stop).Source
$vvp=(Get-Command vvp -ErrorAction Stop).Source
$exe=Join-Path ([System.IO.Path]::GetTempPath()) ("sd_example_"+[guid]::NewGuid().ToString('N')+".vvp")
try {
    $sources=@((Join-Path $lab 'rtl\lab05_spi_byte.v'),(Join-Path $lab 'rtl\lab05_sd_init_read0.v'),(Join-Path $lab 'tests\tb_lab05_sd_init_read0.v'))
    & $iverilog -g2012 -s tb_lab05_sd_init_read0 -o $exe $sources
    if($LASTEXITCODE -ne 0) { throw 'SDHC model compilation failed' }
    & $vvp $exe
    if($LASTEXITCODE -ne 0) { throw 'SDHC model simulation failed' }
} finally {
    Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
}
