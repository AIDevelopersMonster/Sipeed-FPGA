# Independent SPI RTL simulation, no CPU or FPGA programming.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$test=Join-Path $repo '01-PicoRV32\lab05\tools\test_lab05_spi.ps1'
if(-not (Test-Path -LiteralPath $test -PathType Leaf)) { throw "SPI test absent: $test" }
& $test
if(-not $?) { throw 'SPI example test failed' }
