# SD-06 physical video demonstration, Tang Nano 9K, one qualified scratch LBA.
# Read-only by default. -EnableWrite requires a second interactive confirmation.
# -Program explicitly loads the already hardware-tested scratch bitstream to SRAM.
# No rebuild, no configuration flash; never changes FAT32 allocation/metadata.
[CmdletBinding()]
param(
    [string]$Port = 'COM10',
    [switch]$Program,
    [switch]$EnableWrite,
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
)
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$repo = (Resolve-Path (Join-Path $here '..\..\..\..')).Path
$manifest = Join-Path $repo '_reports\sd_rw_scratch\manifest.json'
$backup = Join-Path $repo '_reports\sd_rw_scratch\preimage.bin'
$scratch = Join-Path $here 'tools\scratch_gate.py'
$client = Join-Path $here 'tools\sd_rw.py'
$fs = Join-Path $here 'build\scratch_20261025_091806_636\sd06_scratch_SINGLE_SECTOR.fs'

# Locked to the independently qualified SDHC card-sector test.
$expectedLba = 10718
$expectedSectorSha = 'D4EE72A0614088909BD2B34C5100DE2E7A7370382F2C1E434A0EB2B7460B50F3'
$expectedFsSha = '694D9526525B8AEF99126AF5EF73D7A85216658E707482342521AD035E34F109'
$confirm = 'WRITE-ONE-DISPOSABLE-SD-SCRATCH-SECTOR'
$now = Get-Date -Format 'yyyyMMdd_HHmmss'
$videoDir = Join-Path $repo ("_reports\sd_rw_video_{0}_{1}" -f $now, $PID)
$programmed = $false
$writeStarted = $false
$writeVerified = $false
$restoreVerified = $false

function Step([int]$Number, [string]$Title) {
    Write-Host ''
    Write-Host ("  [{0}/6] {1}" -f $Number, $Title) -ForegroundColor Cyan
    Write-Host '  -------------------------------------------------------------' -ForegroundColor DarkGray
}
function Assert-Hash([string]$Path, [string]$Expected, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label missing: $Path"
    }
    $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
    if ($h -cne $Expected) { throw "$Label SHA256 mismatch: $h" }
    Write-Host "$Label : $h" -ForegroundColor DarkGreen
}
function Invoke-Python([string[]]$Arguments, [string]$Action) {
    & python @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw ("{0} FAIL (exit {1}). No automatic CMD24 retry." -f $Action, $LASTEXITCODE)
    }
}
function Show-SectorBytes([string]$Path, [string]$Label) {
    Write-Host $Label -ForegroundColor Magenta
    Format-Hex -LiteralPath $Path |
        Where-Object { $_.Offset -ge 64 -and $_.Offset -lt 128 } |
        Out-Host
}
function Assert-Sector([string]$Path, [string]$Expected, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label missing" }
    if ((Get-Item -LiteralPath $Path).Length -ne 512) {
        throw "$Label byte length is not 512"
    }
    Assert-Hash -Path $Path -Expected $Expected -Label $Label
}

Clear-Host
Write-Host ''
Write-Host '  =============================================================' -ForegroundColor Cyan
Write-Host '                PiKoSoL / SD-06 LIVE HARDWARE DEMO            ' -ForegroundColor White
Write-Host '      TANG NANO 9K  |  PC -> UART -> FPGA -> SPI -> SDHC      ' -ForegroundColor Yellow
Write-Host '           CMD17 READ   /   CMD24 WRITE   /   RESTORE         ' -ForegroundColor Cyan
Write-Host '  =============================================================' -ForegroundColor Cyan
Write-Host ''
Write-Host ("  Port: {0}    Sector: LBA {1}    Size: 512 bytes" -f $Port,$expectedLba)
Write-Host '  Status: independent SD controller; NOT PicoRV32-MMIO yet.' -ForegroundColor DarkYellow
Write-Host '  Safety: only the disposable FAT32 test card SDRWTEST.BIN.' -ForegroundColor Yellow
if ($EnableWrite) {
    Write-Host '  MODE: physical WRITE + READBACK + RESTORE (confirmation required)' -ForegroundColor Yellow
} else {
    Write-Host '  MODE: READ-ONLY (add -EnableWrite for physical demonstration)' -ForegroundColor Green
}

try {
    Step 1 'IDENTITY / BACKUP / PERMITTED SECTOR'
    Invoke-Python -Action 'Local scratch manifest verification' -Arguments @(
        $scratch, 'validate', '--manifest', $manifest, '--backup', $backup
    )
    $doc = Get-Content -LiteralPath $manifest -Raw | ConvertFrom-Json
    if ([long]$doc.scratch_lba -ne $expectedLba) {
        throw "Scratch LBA differs: $($doc.scratch_lba)"
    }
    if ($doc.file_name -cne 'SDRWTEST.BIN') { throw 'Not the qualified scratch file' }
    if ($doc.preimage_sha256 -cne $expectedSectorSha) { throw 'Unknown scratch preimage' }
    Assert-Hash -Path $backup -Expected $expectedSectorSha -Label 'ORIGINAL SECTOR'
    if ($Program) {
        Assert-Hash -Path $fs -Expected $expectedFsSha -Label 'FPGA SRAM BITSTREAM'
        $prog = Join-Path $GowinRoot 'Programmer\bin\programmer_cli.exe'
        if (-not (Test-Path -LiteralPath $prog -PathType Leaf)) {
            throw "Gowin Programmer missing: $prog"
        }
        Write-Host 'Programming FPGA volatile SRAM; configuration Flash untouched.' -ForegroundColor Yellow
        & $prog --device GW1NR-9C --operation_index 2 --fsFile (Resolve-Path -LiteralPath $fs).Path --cable-index 1
        if ($LASTEXITCODE -ne 0) { throw 'FPGA SRAM programming failed' }
        $programmed = $true
        Write-Host 'FPGA_SRAM_PROGRAM_PASS' -ForegroundColor Green
    } else {
        Write-Host 'FPGA firmware must already be resident in SRAM (or rerun with -Program).' -ForegroundColor DarkYellow
    }

    New-Item -ItemType Directory -Path $videoDir -Force | Out-Null
    Write-Host "Evidence folder: $videoDir" -ForegroundColor Gray

    Step 2 'REAL SDHC PREFLIGHT: MBR / FAT32 / SECTOR PREIMAGE'
    Invoke-Python -Action 'Card validation' -Arguments @(
        $scratch, 'preflight', '--port', $Port, '--manifest', $manifest, '--backup', $backup
    )

    Step 3 'CMD17: READ 512 BYTES FROM REAL MICROSD'
    $before = Join-Path $videoDir 'sector_before.bin'
    Invoke-Python -Action 'Physical CMD17' -Arguments @(
        $client, '--port', $Port, 'read', '--lba', "$expectedLba", '--out', $before
    )
    Assert-Sector -Path $before -Expected $expectedSectorSha -Label 'CMD17 BEFORE'
    Show-SectorBytes -Path $before -Label 'ORIGINAL DATA [OFFSET 0x40..0x7F]:'

    if (-not $EnableWrite) {
        Write-Host ''
        Write-Host '  =============================================================' -ForegroundColor Green
        Write-Host '  LIVE CMD17 READ-ONLY PASS. NO SD SECTOR WAS WRITTEN.' -ForegroundColor Green
        Write-Host '  =============================================================' -ForegroundColor Green
        Write-Host "  Saved: $videoDir"
        return
    }

    Step 4 'CMD24: PHYSICAL WRITE TO ONE LOCKED LBA'
    Write-Host 'The card sector will be changed, then restored from the verified preimage.' -ForegroundColor Yellow
    Write-Host 'DO NOT proceed if this is not the same disposable FAT32 test card.' -ForegroundColor Yellow
    $answer = Read-Host 'To issue a REAL CMD24, type WRITE (or press ENTER to stop)'
    if ($answer -cne 'WRITE') {
        Write-Host 'CANCELLED: no SD write command issued.' -ForegroundColor Yellow
        return
    }
    $writeStarted = $true
    Invoke-Python -Action 'CMD24 write + card readback' -Arguments @(
        $scratch, 'write', '--port', $Port, '--manifest', $manifest,
        '--backup', $backup, '--confirm', $confirm
    )
    $writeVerified = $true

    Step 5 'CMD17: INDEPENDENT READBACK / BYTE CHANGE'
    $after = Join-Path $videoDir 'sector_written.bin'
    Invoke-Python -Action 'Independent physical CMD17 readback' -Arguments @(
        $client, '--port', $Port, 'read', '--lba', "$expectedLba", '--out', $after
    )
    Assert-Sector -Path $after -Expected $doc.newimage_sha256 -Label 'CMD17 WRITTEN'
    $a = [IO.File]::ReadAllBytes($before)
    $b = [IO.File]::ReadAllBytes($after)
    $changed = 0
    for ($i=0; $i -lt 512; $i++) {
        if ($a[$i] -ne $b[$i]) { $changed++ }
    }
    if ($changed -ne 448) { throw "Unexpected changed byte count: $changed" }
    Write-Host "BYTES_CHANGED: $changed / 512 (first 64 identity bytes untouched)" -ForegroundColor Green
    Show-SectorBytes -Path $after -Label 'NEW DATA [OFFSET 0x40..0x7F]:'
    Write-Host 'WRITTEN_DATA_VERIFY_PASS' -ForegroundColor Green
    Write-Host 'Restoring original sector automatically...' -ForegroundColor Yellow
    Start-Sleep -Seconds 3

    Step 6 'CMD24 RESTORE + FINAL CMD17 VERIFY'
    Invoke-Python -Action 'Physical CMD24 restore + card readback' -Arguments @(
        $scratch, 'restore', '--port', $Port, '--manifest', $manifest,
        '--backup', $backup, '--confirm', $confirm
    )
    $restored = Join-Path $videoDir 'sector_restored.bin'
    Invoke-Python -Action 'Final independent CMD17' -Arguments @(
        $client, '--port', $Port, 'read', '--lba', "$expectedLba", '--out', $restored
    )
    Assert-Sector -Path $restored -Expected $expectedSectorSha -Label 'CMD17 RESTORED'
    if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($before)) -cne
        [Convert]::ToBase64String([IO.File]::ReadAllBytes($restored))) {
        throw 'Restored sector differs byte-for-byte from original'
    }
    Invoke-Python -Action 'Final unchanged FAT32/sector verification' -Arguments @(
        $scratch, 'preflight', '--port', $Port, '--manifest', $manifest, '--backup', $backup
    )
    $restoreVerified = $true

    [ordered]@{
        test = 'SD06_LIVE_HARDWARE_VIDEO'
        date = (Get-Date).ToString('o')
        board = 'Tang Nano 9K'
        mode = 'SRAM only'
        port = $Port
        scratch_lba = $expectedLba
        bitstream_sha256 = $expectedFsSha
        original_sha256 = $expectedSectorSha
        written_sha256 = $doc.newimage_sha256
        restored_sha256 = $expectedSectorSha
        changed_bytes = $changed
        original_restored = $true
        status = 'PASS'
    } | ConvertTo-Json -Depth 3 | Set-Content -LiteralPath (Join-Path $videoDir 'demo_receipt.json') -Encoding utf8

    Write-Host ''
    Write-Host '  =============================================================' -ForegroundColor Green
    Write-Host '                 SD-06 LIVE HARDWARE PASS                      ' -ForegroundColor Green
    Write-Host '  CMD17 READ  +  CMD24 WRITE  +  CMD17 VERIFY : PASS          ' -ForegroundColor Green
    Write-Host '  CMD24 RESTORE  +  FINAL CMD17 VERIFY       : PASS          ' -ForegroundColor Green
    Write-Host '  ORIGINAL 512 BYTES FULLY RESTORED. FAT32 INTACT.            ' -ForegroundColor Green
    Write-Host '  =============================================================' -ForegroundColor Green
    Write-Host "  EVIDENCE: $videoDir" -ForegroundColor White
} catch {
    Write-Host ''
    Write-Host ('LIVE_DEMO_STOP: ' + $_.Exception.Message) -ForegroundColor Red
    if ($writeStarted -and -not $restoreVerified) {
        Write-Host 'IMPORTANT: scratch sector may be modified. DO NOT blindly repeat CMD24.' -ForegroundColor Yellow
        Write-Host "Backups: $backup and $manifest" -ForegroundColor Yellow
        Write-Host 'Use independent read-only inspection before any further write attempt.' -ForegroundColor Yellow
    }
    throw
}
