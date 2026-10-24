# SD-04 read-only behavioral regression: decoder, UART/mock integration and HDL top.
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$core=Join-Path $here '..\..\cores\sdhc-spi-readonly\v1\rtl'
$cases=@(
  @{Name='sd04_directory';Top='tb_sd04_directory';Sources=@(
    'rtl\sd04_directory_parser.v','tests\tb_sd04_directory.v');Marker='SD04_DIRECTORY_TB_PASS'},
  @{Name='sd04_mock';Top='tb_sd04_top_mock';Sources=@(
    'rtl\sd04_directory_parser.v','rtl\sd04_uart_report.v',
    'rtl\sd04_directory_probe_top.v','tests\tb_sd04_top_mock.v');Marker='SD04_TOP_MOCK_PASS'}
)
foreach($t in $cases){
  $outfile=Join-Path ([IO.Path]::GetTempPath()) ($t.Name+'_'+[guid]::NewGuid().ToString('N')+'.vvp')
  try {
    $sources=@($t.Sources | ForEach-Object {Join-Path $here $_})
    & iverilog -g2005 -s $t.Top -o $outfile @sources
    if($LASTEXITCODE -ne 0){throw "Compile failed: $($t.Name)"}
    $lines=@(& vvp $outfile);$rc=$LASTEXITCODE
    $lines | ForEach-Object {Write-Host $_}
    if($rc -ne 0 -or -not (($lines -join [char]10).Contains($t.Marker))){
      throw "Simulation failed: $($t.Name)"
    }
  } finally {
    Remove-Item -LiteralPath $outfile -Force -ErrorAction SilentlyContinue
  }
}
Write-Host 'SD04_LOCAL_SIM_PASS'
Write-Host 'No FPGA programmed, no SD card modified.'
