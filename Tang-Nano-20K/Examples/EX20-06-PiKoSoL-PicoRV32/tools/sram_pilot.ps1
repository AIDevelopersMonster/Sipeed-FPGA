# EX20-06: strictly gated FPGA SRAM-only pilot, never writes configuration Flash.
# Default: read-only audit + device scan; -Program requires interactive confirmation.
[CmdletBinding()]
param(
    [switch]$Program,
    [int]$CableIndex = 1,
    [string]$Programmer = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education\Programmer\bin\programmer_cli.exe'
)
$ErrorActionPreference = 'Stop'
$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Job = Join-Path $Root 'build\candidate_20261114_062849_118'
$Pnr = Join-Path $Job 'work\impl\pnr'
$Fs = Join-Path $Pnr 'pikosol20k_picorv32_candidate.fs'
$Pin = Join-Path $Pnr 'pikosol20k_picorv32_candidate.pin.html'
$Rpt = Join-Path $Pnr 'pikosol20k_picorv32_candidate.rpt.txt'
$Gate = Join-Path $Job 'STA_GATE.json'
$Expected = '1841025391F82868B50B2BDF54B0C2D1152392767B76D6F185B1A82162E31AE2'

foreach ($p in @($Fs, $Pin, $Rpt, $Gate, $Programmer)) {
    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { throw "MISSING: $p" }
}
$Actual = (Get-FileHash -LiteralPath $Fs -Algorithm SHA256).Hash
if ($Actual -ine $Expected) { throw "UNEXPECTED BITSTREAM SHA256: $Actual" }
if ((Get-Item -LiteralPath $Fs).Length -ne 7264150) {
    throw 'Unexpected bitstream length. STOP.'
}

$Sta = Get-Content -LiteralPath $Gate -Raw | ConvertFrom-Json
if ($Sta.decision -ne 'PASS_FOR_IO_REVIEW_NOT_BOARD') { throw "STA GATE: $($Sta.decision)" }
foreach ($property in $Sta.checks.PSObject.Properties) {
    if ($property.Value -ne $true) {
        throw "STA CHECK FAILED: $($property.Name)"
    }
}
if (($Sta.setup_violated_endpoints -ne 0) -or ($Sta.hold_violated_endpoints -ne 0)) {
    throw 'Timing violations present: STOP.'
}

# Check Gowin *fitted pin report*, not only input CST.
$html = Get-Content -LiteralPath $Pin -Raw
$row = [regex]::Match($html,'(?is)<tr\b[^>]*>\s*<td\b[^>]*class="label"[^>]*>\s*reset_btn\s*</td>.*?</tr>')
if (-not $row.Success) { throw 'Pin report lacks reset_btn row' }
$cells = @([regex]::Matches($row.Value,'(?is)<td\b[^>]*>(.*?)</td>') |
    ForEach-Object {
        [System.Net.WebUtility]::HtmlDecode(
            ([regex]::Replace($_.Groups[1].Value,'<[^>]+>','')).Trim()
        )
    })
if ($cells.Count -lt 16) { throw "Unexpected reset_btn report row: $($cells.Count) cells" }
if ($cells[2] -ne '88/3' -or $cells[6] -ne 'LVCMOS33' -or $cells[-1] -ne '3.3') {
    throw "Pin88 IO MISMATCH: location=$($cells[2]), type=$($cells[6]), BankVccio=$($cells[-1])"
}

# The PR1014 warning is not suppressed. It is a known limitation of the
# on-board 27-MHz input at pin 4; inspect the physical clock report each time.
$ClockReport = Get-Content -LiteralPath $Rpt -Raw
if ($ClockReport -notmatch '(?m)^\s*clk27_d\s*\|\s*PRIMARY\s*\|\s*TR TL BR BL' -or
    $ClockReport -notmatch '(?m)^\s*pix_clk\s*\|\s*PRIMARY\s*\|\s*TR TL BR BL' -or
    $ClockReport -notmatch '(?m)^\s*serial_clk\s*\|\s*HCLK\s*\|') {
    throw 'Unexpected clock routing summary: STOP'
}

Write-Host 'EX20-06 PRECHECK PASS: exact SHA, STA, RESET PIN 88 (3.3 V), clock placement.'
Write-Host "FPGA IMAGE: $Fs"
Write-Host "SHA256: $Actual"
Write-Warning 'PR1014 known routing warning remains; this is an experimental SRAM trial, NOT BOARD PASS.'
Write-Host 'Closing MobaXterm / other COM and JTAG clients before scan is required.'
Write-Host 'Checking JTAG cable and connected device; NO PROGRAM operation yet.'
& $Programmer --scan --cable-index $CableIndex
$rc = $LASTEXITCODE
if ($rc -ne 0) { throw "JTAG scan failed (exit $rc); STOP." }

if (-not $Program) {
    Write-Host 'EX20-06 JTAG PRECHECK COMPLETE. No FPGA programming performed.'
    Write-Host 'Inspect scan output: must contain exactly one compatible GW2AR-18C (JTAG ID 0x0000081B).'
    Write-Host 'To run the pilot later, explicitly invoke this script with -Program.'
    return
}

Write-Host ''
Write-Warning 'LAST MANUAL CHECK: one GW2AR-18C (ID 0x0000081B), Tang Nano 20K; no attached external PMOD/unsafe circuits.'
Write-Warning 'This changes the active FPGA configuration only. It may temporarily interrupt HDMI and COM. The factory Flash must remain unchanged.'
$confirmation = Read-Host 'Enter EXACTLY "GW2AR-18C SRAM ONLY" after checking scan output'
if ($confirmation -cne 'GW2AR-18C SRAM ONLY') { throw 'Not confirmed; no programming performed' }
& $Programmer --device GW2AR-18C --run 2 --fsFile $Fs --cable-index $CableIndex
$rc = $LASTEXITCODE
if ($rc -ne 0) { throw "Gowin SRAM programming command failed (exit $rc)." }
Write-Host 'GOWIN SRAM COMMAND EXIT 0. This is NOT proof of HDMI/UART/CPU functionality.'
Write-Host 'Now reopen COM25 at 115200 8N1, check PiKoSoL> banner, HDMI native 720p, LED and GFX.'
Write-Host 'Power-cycle board to restore nonvolatile configuration. Never use a Flash operation.'
