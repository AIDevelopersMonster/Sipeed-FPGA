# Read-only simulation, no FPGA programming.
$ErrorActionPreference = 'Stop'
$here=$PSScriptRoot
$out=Join-Path ([IO.Path]::GetTempPath()) ('sd03_'+[guid]::NewGuid().ToString('N')+'.vvp')
try {
  & iverilog -g2005 -s tb_sd03_mbr -o $out (Join-Path $here 'rtl\sd03_mbr_parser.v') (Join-Path $here 'tests\tb_sd03_mbr.v')
  if ($LASTEXITCODE -ne 0) { throw 'SD-03 compile FAIL' }
  $lines=@(& vvp $out)
  $rc=$LASTEXITCODE
  $lines | ForEach-Object { Write-Host $_ }
  if($rc -ne 0 -or -not (($lines -join [char]10).Contains('SD03_MBR_TB_PASS'))) { throw 'SD-03 test FAIL' }
  $other=Join-Path ([IO.Path]::GetTempPath()) ('sd03bpb_'+[guid]::NewGuid().ToString('N')+'.vvp')
  try {
    & iverilog -g2005 -s tb_sd03_fat32_bpb -o $other (Join-Path $here 'rtl\sd03_fat32_bpb.v') (Join-Path $here 'tests\tb_sd03_fat32_bpb.v')
    if($LASTEXITCODE -ne 0){throw 'SD-03 BPB compile FAIL'}
    $outLines=@(& vvp $other); $rc=$LASTEXITCODE
    $outLines | ForEach-Object { Write-Host $_ }
    if($rc -ne 0 -or -not (($outLines -join [char]10).Contains('SD03_FAT32_BPB_TB_PASS'))){throw 'SD-03 BPB test FAIL'}
  } finally {Remove-Item -LiteralPath $other -Force -ErrorAction SilentlyContinue}
} finally { Remove-Item -LiteralPath $out -Force -ErrorAction SilentlyContinue }
