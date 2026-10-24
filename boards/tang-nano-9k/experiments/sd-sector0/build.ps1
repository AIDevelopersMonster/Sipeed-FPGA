[CmdletBinding()]
param([string]$GowinRoot='C:\Gowin\Gowin_V1.9.9Beta-4_Education')
$ErrorActionPreference='Stop'
$here=$PSScriptRoot
$gw=Join-Path $GowinRoot 'IDE\bin\gw_sh.exe'
if(-not (Test-Path -LiteralPath $gw)){ throw "Gowin CLI absent: $gw" }
$job=Join-Path $here ('build\run_'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N').Substring(0,6))
$work=Join-Path $job 'work'
New-Item -ItemType Directory -Force -Path (Join-Path $work 'rtl'),(Join-Path $work 'constraints') | Out-Null
Copy-Item -Path (Join-Path $here 'rtl\*.v') -Destination (Join-Path $work 'rtl')
Copy-Item -Path (Join-Path $here 'constraints\*') -Destination (Join-Path $work 'constraints')
Copy-Item -LiteralPath (Join-Path $here 'build.tcl') -Destination (Join-Path $work 'build.tcl')
@(Get-ChildItem -LiteralPath $work -Recurse -File | Sort-Object FullName | ForEach-Object {
    [pscustomobject]@{
        Path=$_.FullName.Substring($work.Length+1)
        SHA256=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash
    }
}) | Export-Csv -LiteralPath (Join-Path $job 'input_sha256.csv') -Encoding utf8 -NoTypeInformation
Push-Location $work
try {
    & $gw 'build.tcl' *> (Join-Path $job 'gowin_cli.log')
    $exitCode=$LASTEXITCODE
} finally { Pop-Location }
if($exitCode -ne 0){ throw "Gowin failed: $job\gowin_cli.log" }
$bits=@(Get-ChildItem -LiteralPath $work -File -Recurse -Filter 'sd_sector0_nano9k.fs')
if($bits.Count -ne 1){ throw "Unexpected number of bitstreams: $($bits.Count)" }
$fs=Join-Path $job 'sd_sector0_nano9k.fs'
Copy-Item -LiteralPath $bits[0].FullName -Destination $fs
Write-Host "SD01_BITSTREAM_CANDIDATE: $fs"
Write-Host "SD01_SHA256: $((Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash)"
Get-ChildItem -LiteralPath $work -Recurse -File |
  Where-Object { $_.Name -match '\.rpt\.txt$|_tr_content\.html$' } |
  ForEach-Object { Write-Host "SD01_REPORT: $($_.FullName)" }
Write-Host 'SD01_BUILD_ONLY: check PnR and STA before manual SRAM programming. Never Flash.'
