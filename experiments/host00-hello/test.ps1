# HOST-00 RTL verification with actionable Windows/Icarus diagnostics.
# No FPGA programming, no SD writes.
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
$exe=Get-Command iverilog -ErrorAction SilentlyContinue
if(-not $exe){throw 'HOST00_TOOL_MISSING: iverilog not on PATH'}
Write-Host ('HOST00_IVERILOG: '+$exe.Source)
& iverilog -V 2>&1 | Select-Object -First 4 | ForEach-Object {Write-Host $_}
foreach($f in $src){
 if(-not (Test-Path -LiteralPath $f -PathType Leaf)){
  throw ('HOST00_SOURCE_MISSING: '+$f)
 }
 Write-Host ('HOST00_SOURCE: '+[IO.Path]::GetFullPath($f))
}
$out=Join-Path ([IO.Path]::GetTempPath()) ('host00_'+[guid]::NewGuid().ToString('N')+'.vvp')
$log=Join-Path ([IO.Path]::GetTempPath()) ('host00_compile_'+[guid]::NewGuid().ToString('N')+'.log')
try{
 # Keep iverilog stdout and stderr, including filename and line number.
 & iverilog -g2005 -Wall -s tb_host00_hello -o $out @src 2>&1 |
  ForEach-Object {$_ | Out-String | ForEach-Object {Add-Content -LiteralPath $log -Value $_; Write-Host $_}}
 $compileRc=$LASTEXITCODE
 if($compileRc -ne 0){
  Write-Host ('HOST00_COMPILE_LOG: '+$log)
  throw ('HOST00_COMPILE_FAIL: iverilog exit code '+$compileRc)
 }
 Write-Host 'HOST00_COMPILE_PASS'
 $lines=@(& vvp $out 2>&1);$rc=$LASTEXITCODE
 $lines | ForEach-Object {Write-Host $_}
 if($rc -ne 0 -or -not (($lines -join [char]10).Contains('HOST00_HELLO_TB_PASS'))){
  throw ('HOST00_SIM_FAIL: vvp exit code '+$rc)
 }
 Write-Host 'HOST00_LOCAL_SIM_PASS'
}finally{
 Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue
 if(Test-Path -LiteralPath $log){
  if($compileRc -eq 0){Remove-Item -LiteralPath $log -Force -ErrorAction SilentlyContinue}
 }
}
