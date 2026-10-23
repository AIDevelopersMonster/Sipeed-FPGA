# Read-only baseline report discovery. Never claims capacity reports exist.
$ErrorActionPreference='Stop'
$repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
$build = Join-Path $repo '01-PicoRV32\lab04\build'
if (-not (Test-Path -LiteralPath $build -PathType Container)) {
    Write-Host "LAB05_RESOURCE_PENDING: no local LAB-04 build folder: $build"
    exit 0
}
$items = @(Get-ChildItem -LiteralPath $build -Recurse -File |
  Where-Object { $_.Extension -in @('.rpt','.txt','.html','.log') -and $_.FullName -match 'cpu_' } |
  Sort-Object LastWriteTime -Descending)
Write-Host "LAB05_RESOURCE_REPORT_CANDIDATES=$($items.Count)"
$items | Select-Object -First 30 FullName,Length,LastWriteTime | Format-Table -AutoSize
Write-Host "Note: baseline resource use is not known until synthesis/PnR reports are inspected. STA slack does not establish LUT/BSRAM fit margin."
