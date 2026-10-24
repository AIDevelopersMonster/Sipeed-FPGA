$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$iv=(Get-Command iverilog -ErrorAction Stop).Source
$vvp=(Get-Command vvp -ErrorAction Stop).Source
$out=Join-Path ([IO.Path]::GetTempPath()) ('sd02_'+[guid]::NewGuid().ToString('N')+'.vvp')
try {
  & $iv -g2012 -s tb_sd02_multilba -o $out (Join-Path $here 'rtl\spi_byte.v') (Join-Path $here 'rtl\sd_read_sector.v') (Join-Path $here 'tests\tb_sd02_multilba.v')
  if($LASTEXITCODE -ne 0){throw 'compile failed'}
  $lines=@(& $vvp $out)
  $rc=$LASTEXITCODE
  $lines | ForEach-Object { Write-Host $_ }
  if($rc -ne 0 -or -not (($lines -join [char]10).Contains('SD02_MULTI_LBA_TB_PASS'))){throw 'SD-02 test failed'}
} finally { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
