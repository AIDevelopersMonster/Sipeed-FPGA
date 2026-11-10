# TP20-01: diagnose BL616 serial access and READ the MS5351 clock config.
# No FPGA programming, no configuration Flash writes, no pll_clk modification commands.
# Ctrl+X Ctrl+C Enter switches the transient BL616 serial forwarding session to its shell.
# Source: Sipeed Wiki Tang Nano 20K Unbox; "pll_clk" with no args displays frequencies.
[CmdletBinding()]
param(
    [string]$Port = 'COM25',
    [int]$Baud = 115200
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$evidence = Join-Path $root 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$log = Join-Path $evidence "TP20_PLL_PROBE_$stamp.txt"
$transcript = New-Object System.Collections.Generic.List[string]
function Note([string]$Line) {
    Write-Host $Line
    [void]$transcript.Add($Line)
}
function Capture([System.IO.Ports.SerialPort]$Serial, [string]$Label) {
    $s = $Serial.ReadExisting()
    if ($s.Length -gt 0) {
        Note "[$Label]"
        Note $s
    } else {
        Note "[$Label] (no response)"
    }
}
function Save-Transcript {
    $transcript | Set-Content -LiteralPath $log -Encoding UTF8
    Write-Host "EVIDENCE: $log"
}

Note "== TP20-01 USB UART + BL616 MS5351 read-only diagnostic =="
Note "TARGET=$Port BAUD=$Baud; NO FLASH; NO PLL WRITES"
Note "PROGRAMMER LAST REPORTED: Status Code=0x00006020, User Code=0x0000FB41"
try {
    Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
} catch {}
try {
    $ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
    Note ("AVAILABLE COM PORTS: " + $(if ($ports.Count -eq 0) { '(none)' } else { $ports -join ', ' }))
} catch {
    Note "SERIAL PORT ENUMERATION FAILED: $($_.Exception.Message)"
    Save-Transcript
    throw
}
try {
    $pnp = @(Get-CimInstance Win32_PnPEntity -ErrorAction Stop |
        Where-Object { $_.Name -match '\(COM[0-9]+\)' } |
        Select-Object -ExpandProperty Name)
    foreach ($entry in $pnp) { Note "PNP: $entry" }
} catch {
    Note "PNP LIST UNAVAILABLE: $($_.Exception.Message)"
}
if ($ports -notcontains $Port) {
    Note "DIAGNOSIS: $Port is NOT ENUMERATED. Do not write Flash. Check listed COM ports/device manager, USB cable or driver."
    Note "If your board is now on COMxx, rerun: .\tp20-pll-probe.ps1 -Port COMxx"
    Save-Transcript
    return
}

$serial = $null
try {
    $serial = [System.IO.Ports.SerialPort]::new(
        $Port, $Baud,
        [System.IO.Ports.Parity]::None, 8,
        [System.IO.Ports.StopBits]::One
    )
    $serial.ReadTimeout = 500
    $serial.WriteTimeout = 500
    $serial.Handshake = [System.IO.Ports.Handshake]::None
    $serial.DtrEnable = $false
    $serial.RtsEnable = $false
    $serial.Open()
    Note "SERIAL OPEN: PASS"
    Start-Sleep -Milliseconds 300
    Capture $serial 'INITIAL'
    # Official Sipeed sequence: Ctrl+X, Ctrl+C, Enter -> BL616 terminal.
    $serial.Write([byte[]](0x18), 0, 1)
    Start-Sleep -Milliseconds 120
    $serial.Write([byte[]](0x03), 0, 1)
    Start-Sleep -Milliseconds 120
    $serial.Write([byte[]](0x0D), 0, 1)
    Start-Sleep -Milliseconds 750
    Capture $serial 'BL616 SHELL'
    # No arguments = show current O0/O1/O2, without changing the clock.
    $serial.Write("pll_clk" + [char]13)
    Start-Sleep -Milliseconds 900
    Capture $serial 'PLL_CLOCKS'
    Start-Sleep -Milliseconds 400
    Capture $serial 'REMAINING'
    Note "DIAGNOSTIC END: Serial session was switched to BL616 shell temporarily; clocks unchanged."
} catch {
    Note "DIAGNOSIS: OPEN/PROBE FAILED: $($_.Exception.GetType().Name): $($_.Exception.Message)"
    Note "If Access Denied/Port in use: close PuTTY, MobaXterm, Tera Term, Arduino Serial Monitor, Python serial jobs and retry."
    Note "If no BL616 response despite OPEN PASS: check COM selection and BL616 firmware; do not write Flash."
} finally {
    if ($null -ne $serial) {
        if ($serial.IsOpen) { $serial.Close() }
        $serial.Dispose()
    }
    Save-Transcript
}
