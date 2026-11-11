# HOST-01 independent module tests; no board programming.
$ErrorActionPreference='Stop'
$root=$PSScriptRoot
$repo=Join-Path $root '..\..'
$src=@(
 (Join-Path $repo 'cores\crc16-ccitt\v1\rtl\crc16_ccitt_byte.v'),
 (Join-Path $root 'rtl\host01_sector_engine.v'),
 (Join-Path $root 'tests\tb_host01_mock.v')
)
$out=Join-Path ([IO.Path]::GetTempPath()) ('host01_'+[guid]::NewGuid().ToString('N')+'.vvp')
try{
 & iverilog -g2005 -s tb_host01_mock -o $out @src 2>&1|ForEach-Object {Write-Host $_}
 if($LASTEXITCODE -ne 0){throw 'HOST01_COMPILE_FAIL'}
 $log=@(& vvp $out 2>&1);$rc=$LASTEXITCODE
 $log|ForEach-Object {Write-Host $_}
 if($rc -ne 0 -or -not (($log -join [char]10).Contains('HOST01_MOCK_512_PASS'))){throw 'HOST01_MOCK_FAIL'}
 python -m unittest discover -s (Join-Path $root 'tests') -p 'test_*.py' -v
 if($LASTEXITCODE -ne 0){throw 'HOST01_PYTHON_TEST_FAIL'}
 Write-Host 'HOST01_LOCAL_SIM_PASS'
}finally{Remove-Item -LiteralPath $out -ErrorAction SilentlyContinue}
