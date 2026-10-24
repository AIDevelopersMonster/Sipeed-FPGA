# HOST-00 RTL verification, no FPGA programming or SD writes.
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$src=@(
 (Join-Path $root '..\..\cores\uart-8n1\v1\rtl\uart_tx_8n1.v'),
 (Join-Path $root '..\..\cores\uart-8n1\v1\rtl\uart_rx_8n1.v'),
 (Join-Path $root '..\..\cores\fifo-sync\v1\rtl\sync_fifo.v'),
 (Join-Path $root 'rtl\host00_hello.v'),
 (Join-Path $root 'rtl\host00_uart_hello_top.v'),
 (Join-Path $root 'tests\tb_host00_hello.v')
)
$out=Join-Path ([IO.Path]::GetTempPath()) ('host00_'+[guid]::NewGuid().ToString('N')+'.vvp')
try{
 & iverilog -g2005 -s tb_host00_hello -o $out @src
 if($LASTEXITCODE -ne 0){throw 'HOST00 compile FAIL'}
 $log=@(& vvp $out);$rc=$LASTEXITCODE
 $log|ForEach-Object{Write-Host $_}
 if($rc -ne 0 -or -not (($log -join [char]10).Contains('HOST00_HELLO_TB_PASS'))){throw 'HOST00 simulation FAIL'}
}finally{Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue}
