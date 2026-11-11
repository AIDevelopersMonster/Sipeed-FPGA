#requires -Version 7.0
<#
.SYNOPSIS
RS-003 Breakout RGB operator keyboard -> Tang Nano 9K USB UART (FT2232 B).
.DESCRIPTION
CLI-only on Windows: polls physical key states and writes ASCII command bytes
to the chosen COM port. Hold left/right arrows (or A/D); release sends the
corresponding key-up byte. No JTAG, SRAM or Flash access.
.EXAMPLE
.\games\breakout-rgb\tools\control_breakout.ps1 -PortName COM10
#>
[CmdletBinding()]
param(
    [ValidatePattern('^COM[0-9]+$')]
    [string]$PortName = '',
    [ValidateRange(5, 100)]
    [int]$PollMilliseconds = 15
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $IsWindows) {
    throw 'RS-003 keyboard controller supports Windows console sessions only.'
}

$ports = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
if ($ports.Count -eq 0) {
    throw 'No serial ports visible. Check FT2232 interface B / VCP driver.'
}
if (-not $PortName) {
    if ($ports.Count -eq 1) {
        $PortName = $ports[0]
        Write-Host "Auto-selected sole serial port: $PortName"
    } else {
        Write-Host ('Available ports: ' + ($ports -join ', '))
        throw 'More than one COM port found. Specify -PortName COMx for FT2232 UART channel B.'
    }
}
if ($ports -notcontains $PortName) {
    throw "COM port $PortName not present. Available: $($ports -join ', ')"
}

# GetAsyncKeyState detects releases; Console.ReadKey has no key-up event.
if (-not ('RS003Keyboard' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RS003Keyboard {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);
}
'@
}
function Test-KeyDown([int]$VirtualKey) {
    return (([int][RS003Keyboard]::GetAsyncKeyState($VirtualKey) -band 0x8000) -ne 0)
}

# Do not toggle hardware reset lines. UART only.
$serial = [System.IO.Ports.SerialPort]::new(
    $PortName, 115200, [System.IO.Ports.Parity]::None,
    8, [System.IO.Ports.StopBits]::One
)
$serial.Handshake = [System.IO.Ports.Handshake]::None
$serial.DtrEnable = $false
$serial.RtsEnable = $false
$serial.WriteTimeout = 1500
$serial.Encoding = [System.Text.Encoding]::ASCII

$prevLeft = $false
$prevRight = $false
$prevStart = $false
$prevRestart = $false
$prevPalette = @($false, $false, $false, $false)
try {
    $serial.Open()
    $serial.Write('x')   # release any stale keys
    Write-Host ''
    Write-Host "RS003 BREAKOUT UART CONNECTED: $PortName 115200 8N1" -ForegroundColor Green
    Write-Host 'Focus THIS PowerShell window to control the physical FPGA.'
    Write-Host 'LEFT / A          : paddle left (hold)'
    Write-Host 'RIGHT / D         : paddle right (hold)'
    Write-Host 'P / SPACE / ENTER : launch ball'
    Write-Host 'R                 : restart game'
    Write-Host '1 2 3 4           : select palette'
    Write-Host 'Q / ESC           : quit (release both keys)'
    Write-Host ''

    while ($true) {
        $left = (Test-KeyDown 0x25) -or (Test-KeyDown 0x41)
        $right = (Test-KeyDown 0x27) -or (Test-KeyDown 0x44)
        if ($left -ne $prevLeft) {
            $serial.Write($(if ($left) { 'w' } else { 'W' }))
            $prevLeft = $left
        }
        if ($right -ne $prevRight) {
            $serial.Write($(if ($right) { 's' } else { 'S' }))
            $prevRight = $right
        }

        $start = (Test-KeyDown 0x50) -or (Test-KeyDown 0x20) -or (Test-KeyDown 0x0D)
        if ($start -and -not $prevStart) {
            $serial.Write('p')
            Write-Host 'START'
        }
        $prevStart = $start

        $restart = Test-KeyDown 0x52
        if ($restart -and -not $prevRestart) {
            $serial.Write('r')
            Write-Host 'RESTART'
        }
        $prevRestart = $restart

        foreach ($i in 1..4) {
            $pressed = (Test-KeyDown (0x30 + $i)) -or (Test-KeyDown (0x60 + $i))
            if ($pressed -and -not $prevPalette[$i - 1]) {
                $serial.Write([string]$i)
                Write-Host "PALETTE $i"
            }
            $prevPalette[$i - 1] = $pressed
        }

        if ((Test-KeyDown 0x51) -or (Test-KeyDown 0x1B)) { break }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
}
finally {
    if ($serial.IsOpen) {
        try { $serial.Write('x') } catch { Write-Warning 'Unable to release paddle keys on exit' }
        $serial.Close()
    }
    $serial.Dispose()
    Write-Host 'RS003 BREAKOUT UART DISCONNECTED'
}
