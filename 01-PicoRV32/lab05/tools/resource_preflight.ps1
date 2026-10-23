# LAB-05.1: read-only discovery of LAB-04 CPU Gowin resource report candidates.
# Use -BaselineRepo when testing LAB-05 in a separate Git worktree.
[CmdletBinding()]
param(
    [string]$BaselineRepo
)
$ErrorActionPreference = 'Stop'
if ($BaselineRepo) {
    $repo = (Resolve-Path -LiteralPath $BaselineRepo -ErrorAction Stop).Path
} else {
    $repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
}
$build = Join-Path $repo '01-PicoRV32\lab04\build'
Write-Host "LAB05_BASELINE_REPO: $repo"
if (-not (Test-Path -LiteralPath $build -PathType Container)) {
    Write-Host "LAB05_RESOURCE_PENDING: no local LAB-04 build folder: $build"
    Write-Host 'Pass -BaselineRepo C:\GitHub\Sipeed-FPGA if you are in an isolated LAB-05 worktree.'
    exit 0
}
$items = @(Get-ChildItem -LiteralPath $build -Recurse -File |
    Where-Object { $_.Extension -in @('.rpt','.txt','.html','.log') -and $_.FullName -match 'cpu_' } |
    Sort-Object LastWriteTime -Descending)
Write-Host "LAB05_RESOURCE_REPORT_CANDIDATES=$($items.Count)"
$items | Select-Object -First 30 FullName,Length,LastWriteTime | Format-Table -AutoSize
$pattern = 'BSRAM|BRAM|LUT4|LUTs|Logic Utilization|Slice Utilization|Block RAM|resource utilization'
$matchesFound = 0
foreach ($file in ($items | Select-Object -First 20)) {
    $hits = @(Select-String -LiteralPath $file.FullName -Pattern $pattern -ErrorAction SilentlyContinue | Select-Object -First 8)
    foreach ($hit in $hits) {
        $line = ($hit.Line -replace '\s+', ' ').Trim()
        if ($line.Length -gt 220) { $line = $line.Substring(0,220) + '...' }
        Write-Host ("REPORT_CANDIDATE: {0}:{1} {2}" -f $file.Name,$hit.LineNumber,$line)
        $matchesFound++
    }
}
Write-Host "LAB05_RESOURCE_MATCHES=$matchesFound (raw text candidates, NOT certified utilization)"
Write-Host 'LAB05_RESOURCE_GATE_PENDING: inspect the original synthesis and PnR utilization reports; positive STA slack alone is insufficient.'
