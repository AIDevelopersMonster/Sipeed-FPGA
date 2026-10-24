# Independent read-only SD-02 Gowin build. No SRAM or Flash programming.
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
  [pscustomobject]@{
    Path=$_.FullName.Substring($work.Length+1)
    SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
  }
} | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -NoTypeInformation -Encoding utf8
Push-Location $work
try {
  & $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log')
  $code=$LASTEXITCODE
} finally { Pop-Location }
if($code -ne 0){throw "Gowin failed with exit=$code. Review $job\gowin_cli.log"}
$bits=@(Get-ChildItem -LiteralPath $work -Recurse -File -Filter 'sd02_multilba_nano9k.fs')
if($bits.Count -ne 1){throw "Expected one SD02 bitstream, found $($bits.Count)"}
$fs=Join-Path $job 'sd02_multilba_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $fs
Write-Host "SD02_BITSTREAM_CANDIDATE: $fs"
Write-Host "SD02_SHA256: $((Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash)"
Get-ChildItem -LiteralPath $work -Recurse -File | Where-Object {
  $_.Name -match '\.rpt\.txt$|_tr_content\.html$|\.log$'
} | ForEach-Object {Write-Host "SD02_REPORT: $($_.FullName)"}
Write-Host 'SD02_BUILD_ONLY: verify PnR, STA, pin constraints and read-only card operation; SRAM only.'
