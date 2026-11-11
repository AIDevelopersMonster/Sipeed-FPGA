$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$iv=(Get-Command iverilog -ErrorAction Stop).Source
$vvp=(Get-Command vvp -ErrorAction Stop).Source
$exe=Join-Path ([IO.Path]::GetTempPath()) ('spi01_'+[guid]::NewGuid().ToString('N')+'.vvp')
try {
  & $iv -g2012 -s tb_lab05_spi_byte -o $exe (Join-Path $root 'rtl\spi_byte.v') (Join-Path $root 'tests\tb_spi_byte.v')
  if($LASTEXITCODE -ne 0){ throw 'SPI-01 compile failed' }
  $log=@(& $vvp $exe)
  $ec=$LASTEXITCODE
  $log | ForEach-Object { Write-Host $_ }
  if($ec -ne 0 -or -not (($log -join [char]10).Contains('LAB05_SPI_BYTE_TB_PASS'))){ throw 'SPI-01 simulation failed' }
} finally { Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue }
