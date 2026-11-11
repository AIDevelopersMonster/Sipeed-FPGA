# Standalone RTL test. No access to COM, FPGA, microSD or HOST-00.
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$cases=@(
  @{Name='TX';Top='tb_uart';Files=@('rtl\uart_tx_8n1.v','tests\tb_uart_tx.v');Pass='UART TB PASS:'},
  @{Name='RX';Top='tb_uart_rx';Files=@('rtl\uart_rx_8n1.v','tests\tb_uart_rx.v');Pass='LAB02_RX_RTL_PASS:'},
  @{Name='LOOPBACK';Top='tb_uart_loopback';Files=@('rtl\uart_tx_8n1.v','rtl\uart_rx_8n1.v','tests\tb_uart_loopback.v');Pass='UART_CORE_LOOPBACK_PASS:'}
)
foreach($t in $cases){
 $out=Join-Path ([IO.Path]::GetTempPath()) ('uart_'+[guid]::NewGuid().ToString('N')+'.vvp')
 try {
  $files=@($t.Files|ForEach-Object{Join-Path $root $_})
  & iverilog -g2005 -s $t.Top -o $out @files
  if($LASTEXITCODE -ne 0){throw "UART compile FAIL: $($t.Name)"}
  $lines=@(& vvp $out);$rc=$LASTEXITCODE
  $lines|ForEach-Object{Write-Host $_}
  if($rc -ne 0 -or -not (($lines -join [char]10).Contains($t.Pass))){throw "UART simulation FAIL: $($t.Name)"}
 }finally{Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue}
}
Write-Host 'UART_CORE_SIM_PASS: TX, RX and independent loopback'
