# Inspect latest PiKoSoL 20K PnR. Never programs FPGA or SD.
[CmdletBinding()]
param([string]$Python='python')
$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$jobs=@(Get-ChildItem (Join-Path $root 'build') -Directory -Filter 'candidate_*' |
  Where-Object { Test-Path (Join-Path $_.FullName 'gowin.log') } |
  Sort-Object LastWriteTime -Descending)
if($jobs.Count -eq 0){throw 'No Gowin candidate directories'}
$job=$jobs[0].FullName
$pnr=Join-Path $job 'work\impl\pnr'
$report=Join-Path $pnr 'pikosol20k_picorv32_candidate_tr_content.html'
$log=Join-Path $job 'gowin.log'
$sdc=Join-Path $job 'work\constraints\pikosol20k.sdc'
$fs=@(Get-ChildItem (Join-Path $job 'work') -Recurse -Filter '*.fs' -File)
if($fs.Count -gt 1){throw 'Multiple bitstreams: selection ambiguous'}
if(!(Test-Path -LiteralPath $report)){throw "Missing PnR report: $report"}
$result=Join-Path $job 'STA_GATE.json'
$argList=@('--report',$report,'--log',$log,'--sdc',$sdc,'--output',$result)
if($fs.Count -eq 1){$argList+=@('--fs',$fs[0].FullName)}
& $Python (Join-Path $PSScriptRoot 'sta_gate.py') @argList
$rc=$LASTEXITCODE
$archive=Join-Path $root ('build\EX20-06_STA_'+(Split-Path $job -Leaf)+'.zip')
$reports=@(Get-ChildItem (Join-Path $job 'work\impl') -Recurse -File |
  Where-Object { $_.Extension -in '.html','.rpt','.txt' })
$evidence=@($log,$sdc,$result)+@($reports.FullName)
Compress-Archive -LiteralPath $evidence -DestinationPath $archive -Force
Write-Host "STA_GATE_EXIT=$rc"
Write-Host "STA_ARCHIVE=$archive"
Write-Host "FS_COUNT=$($fs.Count)"
if($fs.Count -eq 1){Write-Host "FS_SHA256=$((Get-FileHash $fs[0].FullName -Algorithm SHA256).Hash)"}
if($rc -ne 0){Write-Warning 'STA GATE FAILED or incomplete. Do not program FPGA.'}
