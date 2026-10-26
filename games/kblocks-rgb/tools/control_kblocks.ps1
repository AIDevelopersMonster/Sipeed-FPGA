#requires -Version 7.0
<#
.SYNOPSIS
KonSol RS-004 K-BLOCKS RGB keyboard -> Tang Nano 9K USB-UART (FT2232 B).
.EXAMPLE
.\games\kblocks-rgb\tools\control_kblocks.ps1 -PortName COM10
.DESCRIPTION
CLI-only Windows controller. No FPGA programming or reset toggling.
Use a separate terminal for Gowin SRAM loading. Run from the repository root.
#>
[CmdletBinding()]
param(
    [ValidatePattern('^COM[0-9]+$')]
    [string]$PortName = '',
    [ValidateRange(5,100)]
    [int]$PollMilliseconds = 15
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) { throw 'RS-004 keyboard controller requires Windows.' }
$ports=@([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
if ($ports.Count -eq 0) { throw 'No COM ports. Check FT2232 channel B VCP driver.' }
if (-not $PortName) {
    if ($ports.Count -ne 1) {
        Write-Host "Available COM ports: $($ports -join ', ')"
        throw 'Specify -PortName COMx (FT2232 UART channel B)'
    }
    $PortName=$ports[0]
    Write-Host "Selected sole COM port: $PortName"
}
if ($ports -notcontains $PortName) { throw "COM port $PortName not found. Available: $($ports -join ', ')" }

if (-not ('RS004Keyboard' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class RS004Keyboard {
    [DllImport("user32.dll")]
    public static extern short GetAsyncKeyState(int virtualKey);
}
'@
}
function KeyDown([int]$code) {
    return (([int][RS004Keyboard]::GetAsyncKeyState($code) -band 0x8000) -ne 0)
}

$port=[System.IO.Ports.SerialPort]::new(
    $PortName,115200,[System.IO.Ports.Parity]::None,
    8,[System.IO.Ports.StopBits]::One)
$port.Handshake=[System.IO.Ports.Handshake]::None
$port.DtrEnable=$false
$port.RtsEnable=$false
$port.Encoding=[System.Text.Encoding]::ASCII
$port.WriteTimeout=1500
$leftWas=$false; $rightWas=$false; $downWas=$false
$rotateWas=$false; $startWas=$false; $restartWas=$false
$paletteWas=@($false,$false,$false,$false)
try {
    $port.Open()
    $port.Write('x')
    Write-Host "RS004 K-BLOCKS UART: $PortName 115200 8N1" -ForegroundColor Green
    Write-Host 'Focus this PowerShell window for key tracking.'
    Write-Host 'LEFT / A          : move left (hold)'
    Write-Host 'RIGHT / D         : move right (hold)'
    Write-Host 'DOWN / S          : soft drop (hold)'
    Write-Host 'UP / W            : rotate clockwise (one step/press)'
    Write-Host 'P / SPACE / ENTER : start new game'
    Write-Host 'R                 : reset to ready'
    Write-Host '1, 2, 3, 4       : select palette'
    Write-Host 'Q / ESC           : quit controller'
    Write-Host ''
    while($true) {
        $left= (KeyDown 0x25) -or (KeyDown 0x41)
        $right=(KeyDown 0x27) -or (KeyDown 0x44)
        $down= (KeyDown 0x28) -or (KeyDown 0x53)
        if($left -ne $leftWas) {
            $port.Write($(if($left){'a'}else{'A'})); $leftWas=$left
        }
        if($right -ne $rightWas) {
            $port.Write($(if($right){'d'}else{'D'})); $rightWas=$right
        }
        if($down -ne $downWas) {
            $port.Write($(if($down){'s'}else{'S'})); $downWas=$down
        }
        $rotate=(KeyDown 0x26) -or (KeyDown 0x57)
        if($rotate -and -not $rotateWas) { $port.Write('w') }
        $rotateWas=$rotate
        $start=(KeyDown 0x50) -or (KeyDown 0x20) -or (KeyDown 0x0D)
        if($start -and -not $startWas) {
            $port.Write('p'); Write-Host 'START'
        }
        $startWas=$start
        $restart=KeyDown 0x52
        if($restart -and -not $restartWas) {
            $port.Write('r'); Write-Host 'RESET'
        }
        $restartWas=$restart
        foreach($i in 1..4) {
            $downNow=(KeyDown (0x30+$i)) -or (KeyDown (0x60+$i))
            if($downNow -and -not $paletteWas[$i-1]) {
                $port.Write([string]$i)
                Write-Host "PALETTE $i"
            }
            $paletteWas[$i-1]=$downNow
        }
        if((KeyDown 0x51) -or (KeyDown 0x1B)) { break }
        Start-Sleep -Milliseconds $PollMilliseconds
    }
} finally {
    if($port.IsOpen) {
        try { $port.Write('x') } catch { Write-Warning 'Cannot release key states on exit' }
        $port.Close()
    }
    $port.Dispose()
    Write-Host 'RS004 UART DISCONNECTED'
}
