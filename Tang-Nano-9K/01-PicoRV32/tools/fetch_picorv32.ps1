# Fetch exactly the pinned upstream PicoRV32 revision. Existing checkouts are not overwritten.
param([string]$Revision = 'ef203c2b0a3fb793280f5114941416c425c5b461')
$ErrorActionPreference = 'Stop'
$Base = Split-Path -Parent $PSScriptRoot
$Target = Join-Path $Base 'vendor\picorv32'
$Expected = 'ef203c2b0a3fb793280f5114941416c425c5b461'
if ($Revision -ne $Expected) { throw "Revision differs from sources.lock.json; edit lock intentionally first." }
if (Test-Path $Target) {
    $current = (& git -C $Target rev-parse HEAD 2>$null).Trim()
    if ($LASTEXITCODE -ne 0 -or $current -ne $Expected) {
        throw "Existing vendor/picorv32 is not at pinned SHA. No destructive action performed."
    }
    Write-Host "Pinned PicoRV32 already available at $Target"
    exit 0
}
& git clone 'https://github.com/YosysHQ/picorv32.git' $Target
if ($LASTEXITCODE -ne 0) { throw 'Git clone failed' }
& git -C $Target checkout --detach $Expected
if ($LASTEXITCODE -ne 0) { throw 'Cannot check out locked revision' }
Write-Host "Pinned PicoRV32 fetched: $Expected"
