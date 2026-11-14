# PiKoSoL 20K FONT 1/2 candidate: tests -> Gowin PnR -> report gate.
# Never invokes Gowin Programmer, never changes FPGA Flash or SRAM.
[CmdletBinding()]
param([string]$Python='python')
$ErrorActionPreference='Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Push-Location $Root
try {
    Write-Host '=== EX20-06 FONT: Python syntax and contracts ==='
    & $Python -m py_compile .\tools\stage.py .\tools\sta_gate.py .\tests\test_contract.py
    if ($LASTEXITCODE -ne 0) { throw 'Python syntax test FAIL' }
    & $Python .\tests\test_contract.py
    if ($LASTEXITCODE -ne 0) { throw 'Contract test FAIL' }

    Write-Host '=== EX20-06 FONT: HDL renderer + reset simulations ==='
    & .\tests\run_sim.ps1
    if (-not $?) { throw 'Icarus RTL simulation FAIL' }

    Write-Host '=== EX20-06 FONT: Gowin synthesis + PnR + STA ==='
    & .\build.ps1 -Python $Python
    if (-not $?) { throw 'Gowin build FAIL' }

    Write-Host '=== EX20-06 FONT: independent STA report ==='
    & .\tools\collect_sta.ps1 -Python $Python
    if (-not $?) { throw 'Report collection FAIL' }

    $Jobs = @(Get-ChildItem .\build -Directory -Filter 'candidate_*' |
        Where-Object { Test-Path (Join-Path $_.FullName 'STA_GATE.json') } |
        Sort-Object LastWriteTime -Descending)
    if ($Jobs.Count -eq 0) { throw 'No STA gate JSON from candidate' }
    $Job = $Jobs[0]
    $Gate = Get-Content (Join-Path $Job.FullName 'STA_GATE.json') -Raw | ConvertFrom-Json
    if ($Gate.decision -ne 'PASS_FOR_IO_REVIEW_NOT_BOARD') {
        throw "NEW BITSTREAM NOT QUALIFIED: $($Gate.decision). DO NOT PROGRAM."
    }
    $Pnr = Join-Path $Job.FullName 'work\impl\pnr'
    $Bits = Join-Path $Pnr 'pikosol20k_picorv32_candidate.fs'
    if (-not(Test-Path $Bits)) { throw 'Missing .fs bitstream' }
    Write-Host 'FONT CANDIDATE STA PASS - STILL NOT BOARD PASS'
    Write-Host "Candidate: $($Job.Name)"
    Write-Host "FS: $Bits"
    Write-Host "SHA256: $((Get-FileHash -LiteralPath $Bits -Algorithm SHA256).Hash)"
    Write-Host 'NO FPGA PROGRAMMING PERFORMED.'
} finally {
    Pop-Location
}
