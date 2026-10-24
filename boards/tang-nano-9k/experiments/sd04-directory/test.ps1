# SD-04 read-only local gate. No Gowin programming; no SD writes.
# Requires Icarus Verilog (iverilog/vvp) and Python 3.
$ErrorActionPreference = 'Stop'
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
$exp = Split-Path -Parent $dir
$sd03 = Join-Path $exp 'sd-mbr-fat32'
$work = Join-Path ([System.IO.Path]::GetTempPath()) ("sd04-gate-" + [guid]::NewGuid().ToString('N'))
New-Item -Path $work -ItemType Directory | Out-Null
try {
  & python -m unittest discover -s (Join-Path $dir 'tests') -p 'test_*.py' -v
  if ($LASTEXITCODE -ne 0) { throw 'Python tests FAIL' }

  $deps = @(
    (Join-Path $sd03 'rtl/spi_byte.v'),
    (Join-Path $sd03 'rtl/sd_read_sector.v'),
    (Join-Path $sd03 'rtl/uart_tx_8n1.v'),
    (Join-Path $sd03 'rtl/sd03_mbr_parser.v'),
    (Join-Path $sd03 'rtl/sd03_fat32_bpb.v'),
    (Join-Path $sd03 'rtl/sd03_volume_scanner.v'),
    (Join-Path $dir 'rtl/sd04_root_dump_top.v')
  )
  & iverilog -g2005 -s sd04_root_dump_top -o (Join-Path $work 'top.vvp') @deps
  if ($LASTEXITCODE -ne 0) { throw 'Full dependency RTL compile FAIL' }

  & iverilog -g2005 -s tb_sd04_root_dump -o (Join-Path $work 'tb.vvp') (Join-Path $dir 'rtl/sd04_root_dump_top.v') (Join-Path $dir 'tests/tb_sd04_root_dump.v')
  if ($LASTEXITCODE -ne 0) { throw 'TB compile FAIL' }
  $log = & vvp (Join-Path $work 'tb.vvp') 2>&1
  $rc = $LASTEXITCODE
  $log | ForEach-Object { Write-Host $_ }
  if ($rc -ne 0 -or -not ($log -match 'SD04_ROOT_DUMP_TB_PASS')) { throw 'RTL test FAIL' }
  Write-Host 'SD04_LOCAL_GATE_PASS (simulation only; no STA or board test)'
} finally {
  Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
