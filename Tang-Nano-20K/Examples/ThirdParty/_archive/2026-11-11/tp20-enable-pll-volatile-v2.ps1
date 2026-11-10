# TP20-01 / TP20-02: set volatile MS5351 clocks for nano-Z80.
# v2.2 (2026-11-11) - clean replacement of corrupted v2.1, non-blocking default.
# Does NOT write FPGA configuration Flash, SD or persistent PLL (-s).
# Default invocation is read-only; -Apply requires CLOCKS confirmation.
[CmdletBinding()]
param(
    [string]$Port = 'COM25',
    [int]$Baud = 115200,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$evidenceDir = Join-Path $PSScriptRoot 'evidence'
New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logPath = Join-Path $evidenceDir "TP20_PLL_ENABLE_$stamp.txt"
$script:logLines = New-Object 'System.Collections.Generic.List[string]'

function Log([string]$message) {
    Write-Host $message
    [void]$script:logLines.Add($message)
}
function Read-Response([System.IO.Ports.SerialPort]$Serial, [int]$Ms, [string]$Label) {
    $b = [System.Text.StringBuilder]::new()
    $steps = [Math]::Max(1, [int][Math]::Ceiling($Ms / 100))
    for ($i = 0; $i -lt $steps; $i++) {
        Start-Sleep -Milliseconds 100
        [void]$b.Append($Serial.ReadExisting())
    }
    $response = $b.ToString()
    Log "[$Label]"
    if ($response.Length -gt 0) {
        Log $response
    } else {
        Log '(no response)'
    }
    return $response
}
function Send-Line([System.IO.Ports.SerialPort]$Serial, [string]$Line, [int]$Ms = 1100) {
    Log "TX: $Line"
    $Serial.Write($Line + [char]13)
    return (Read-Response $Serial $Ms $Line)
}

Log '== TP20 MS5351 volatile clocks v2.2 =='
Log "PORT=$Port BAUD=$Baud APPLY=$Apply"
Log 'Target: O0=25175000 Hz, O1=12000000 Hz.'
Log 'Safety: no pll_clk -s, no persistent save, no SD or FPGA writes.'

$serial = $null
$enteredShell = $false
$success = $false
try {
    Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
    $serial = [System.IO.Ports.SerialPort]::new($Port, $Baud, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
    $serial.Handshake = [System.IO.Ports.Handshake]::None
    $serial.DtrEnable = $false
    $serial.RtsEnable = $false
    $serial.ReadTimeout = 600
    $serial.WriteTimeout = 600
    $serial.Open()
    Log 'SERIAL OPEN: PASS'

    $initial = Send-Line $serial '' 650
    if ($initial -notmatch 'TangNano20K\s*/>') {
        Log 'Requesting BL616 shell: Ctrl+X, Ctrl+C, Enter'
        $serial.Write([byte[]](0x18), 0, 1)
        Start-Sleep -Milliseconds 120
        $serial.Write([byte[]](0x03), 0, 1)
        Start-Sleep -Milliseconds 120
        $serial.Write([byte[]](0x0D), 0, 1)
        $initial = Read-Response $serial 1100 'BL616 SHELL'
    }
    if ($initial -notmatch 'TangNano20K\s*/>') {
        throw 'BL616 shell prompt not found; clocks NOT changed. Check COM port and UART routing.'
    }
    $enteredShell = $true

    if ($Apply) {
        $answer = Read-Host 'Type CLOCKS to set both MS5351 outputs temporarily'
        if ($answer -cne 'CLOCKS') { throw 'Operator cancelled before PLL commands.' }
        $null = Send-Line $serial 'pll_clk O0=25175K' 1300
        $null = Send-Line $serial 'pll_clk O1=12M' 1300
        Log 'MS5351 CLOCK COMMANDS SENT. Verification deferred until OS boot.'
    } else {
        $null = Send-Line $serial 'pll_clk' 1300
        Log 'READ-ONLY PLL STATUS RECEIVED. No clocks changed.'
    }
    $success = $true
} catch {
    Log "ERROR: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    $success = $false
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) {
            if ($enteredShell) {
                try {
                    $null = Send-Line $serial 'choose uart' 950
                    Log 'BL616 UART bridge requested for FPGA.'
                } catch {
                    Log 'ERROR: could not request FPGA UART bridge.'
                    $success = $false
                }
            }
            $serial.Close()
        }
        $serial.Dispose()
    }
    $script:logLines | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-Host "EVIDENCE: $logPath"
}
if (-not $success) {
    throw "TP20 PLL commands incomplete. See $logPath"
}
if ($Apply) {
    Write-Host 'PLL COMMANDS SENT (not independently measured); FPGA SRAM remains unchanged.'
    Write-Host 'NEXT: press and release physical S2 RESET, then open COM25 115200/8N1.'
    Write-Host 'At nano-Z80 Ready prompt: type B to boot CP/Mish.'
}
