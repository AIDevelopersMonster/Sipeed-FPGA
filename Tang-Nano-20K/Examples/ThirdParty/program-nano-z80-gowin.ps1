# TP20-01: nano-Z80 programming with the Gowin CLI previously proved on EX20-01.
# Default: DRY RUN. -Scan: read-only JTAG scan. -Program: explicitly requested SRAM-only configuration.
# NEVER invokes Gowin Flash operations or changes the external PLL.
[CmdletBinding()]
param(
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education',
    [string]$Bitstream = (Join-Path $PSScriptRoot 'downloads\nano-z80.fs'),
    [ValidateSet(0,1,2,3)][int]$CableIndex = 1,
    [switch]$Scan,
    [switch]$Program
)
$ErrorActionPreference = 'Stop'
$expectedBytes = 7262008
$expectedSha = '8DD5274B4DA2E85D8877B10D62494802BAE59541B8C964751B5341E1AB055770'
$programmer = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
if (-not (Test-Path -LiteralPath $programmer -PathType Leaf)) {
    throw "Gowin Programmer CLI not found: $programmer. This script does not install drivers."
}
if (-not (Test-Path -LiteralPath $Bitstream -PathType Leaf)) {
    throw "nano-z80 bitstream missing: $Bitstream. Run prepare-tp20.ps1 first."
}
$fs = (Resolve-Path -LiteralPath $Bitstream).Path
if (-not $fs.EndsWith('.fs',[StringComparison]::OrdinalIgnoreCase)) { throw "Only a .fs file is accepted" }
$size = (Get-Item -LiteralPath $fs).Length
$sha = (Get-FileHash -LiteralPath $fs -Algorithm SHA256).Hash
if ($size -ne $expectedBytes -or $sha -ne $expectedSha) {
    throw "Bitstream fingerprint mismatch: bytes=$size, SHA256=$sha. EXPECTED bytes=$expectedBytes SHA256=$expectedSha. Refusing."
}
Write-Host "TP20-01: nano-Z80 FILE VERIFIED"
Write-Host "SIZE=$size SHA256=$sha"
Write-Host "PROGRAMMER=$programmer"
Write-Host "MODE: Gowin --run 2 = SRAM Program ONLY; NEVER FLASH"
Write-Host "CABLE INDEX=$CableIndex; EXPECTED TARGET=GW2AR-18C"
Write-Warning "This command does NOT configure external PLL. HDMI requires O0 25.175MHz; O1 12MHz."
$evidence = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'

if (-not ($Scan -or $Program)) {
    Write-Host "DRY RUN PASS. No JTAG operation. Use -Scan first, then -Program."
    return
}

$scanLog = Join-Path $evidence "TP20_JTAG_SCAN_$stamp.txt"
Write-Host "READ-ONLY JTAG SCAN..."
& $programmer --scan --cable-index $CableIndex 2>&1 | Tee-Object -FilePath $scanLog
$scanExit = $LASTEXITCODE
Write-Host "SCAN LOG: $scanLog"
if ($scanExit -ne 0) { throw "Gowin JTAG scan exited $scanExit; no programming occurred" }
$scanText = Get-Content -LiteralPath $scanLog -Raw
if ($scanText -notmatch '(?i)GW2AR-18C') {
    throw "Expected GW2AR-18C not in scan output. Refusing to program."
}
if (-not $Program) {
    Write-Host "JTAG SCAN PASS. No FPGA configuration changed."
    return
}

Write-Warning "PROGRAM operation replaces the currently running LiteX in FPGA SRAM until power-cycle."
Write-Warning "Close COM terminals and all applications using the board. This uses SRAM only; no Flash operation."
$answer = Read-Host "Type exactly SRAM to authorize temporary FPGA configuration"
if ($answer -cne 'SRAM') { throw "Operator cancelled; no programming performed" }

$programLog = Join-Path $evidence "TP20_SRAM_PROGRAM_$stamp.txt"
& $programmer --device GW2AR-18C --run 2 --fsFile $fs --cable-index $CableIndex 2>&1 | Tee-Object -FilePath $programLog
$programExit = $LASTEXITCODE
Write-Host "PROGRAM LOG: $programLog"
if ($programExit -ne 0) { throw "Gowin SRAM program exited $programExit. No BOARD PASS declared." }
Write-Host "SRAM PROGRAM CLI EXIT 0. Next: HDMI + ROM banner on UART 115200/8N1."
Write-Host "Only operator's physical HDMI/UART/command checks establish BOARD PASS."
