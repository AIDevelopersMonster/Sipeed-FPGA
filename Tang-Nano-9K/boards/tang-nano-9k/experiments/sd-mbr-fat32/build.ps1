# SD-03 isolated Gowin PnR build ONLY. Never programs SRAM or Flash.
[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not (Test-Path -LiteralPath $gw -PathType Leaf)){throw "Missing Gowin CLI: $gw"}
$job=Join-Path $here ('build\run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
$work=Join-Path $job 'work'
New-Item -ItemType Directory -Force -Path (Join-Path $work 'rtl'),(Join-Path $work 'constraints') | Out-Null
Copy-Item -Path (Join-Path $here 'rtl\*.v') -Destination (Join-Path $work 'rtl')
Copy-Item -Path (Join-Path $here 'constraints\*') -Destination (Join-Path $work 'constraints')
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination (Join-Path $work 'build.tcl')
Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName | ForEach-Object {
  [pscustomobject]@{Path=$_.FullName.Substring($work.Length+1);SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
} | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Push-Location $work
try {
  & $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log')
  $code=$LASTEXITCODE
} finally {Pop-Location}
if($code -ne 0){throw "Gowin failed exit=$code; inspect $job\gowin_cli.log"}
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'sd03_mbr_fat32_nano9k.fs')
if($bits.Count -ne 1){throw "Expected one bitstream, found $($bits.Count)"}
$fs=Join-Path $job 'sd03_mbr_fat32_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $fs
Write-Host "SD03_BITSTREAM_CANDIDATE: $fs"
Write-Host "SD03_SHA256: $((Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash)"
Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object {
  $_.Name -match '\.rpt\.txt$|_tr_content\.html$|\.log$'
} | ForEach-Object { Write-Host "SD03_REPORT: $($_.FullName)" }
Write-Host "SD03_BUILD_ONLY: review logic, setup/hold, uncharacterized SD I/O. SRAM-only programming must be explicit."
