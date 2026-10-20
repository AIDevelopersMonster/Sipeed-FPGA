# LAB-02 board-only verification. Physical Tang Nano 9K, onboard USB bridge.
# Read/write serial at 115200 8N1. Never programs FPGA or writes Flash.
param([string]$PortName='COM10', [int]$TimeoutMs=3500)
$ErrorActionPreference='Stop'
if ($TimeoutMs -lt 600) { throw 'TimeoutMs must be at least 600 ms.' }
$sp = [System.IO.Ports.SerialPort]::new($PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$sp.Handshake = [System.IO.Ports.Handshake]::None
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sp.NewLine = "`n"
$sp.ReadTimeout = 150
$sp.WriteTimeout = 1000

function Invoke-DeviceCommand {
    param([System.IO.Ports.SerialPort]$Port,[string]$Command,[int]$WaitMs)
    $Port.DiscardInBuffer() # Only fresh lines count as an ACK.
    $Port.Write($Command)  # ASCII digit or '?', no CR/LF required.
    $watch = [System.Diagnostics.Stopwatch]::StartNew()
    $unexpected = @()
    while ($watch.ElapsedMilliseconds -lt $WaitMs) {
        try {
            $line = $Port.ReadLine().Trim()
            if ($line -match '^L=([0-6])$') { return $line }
            if ($line -in @('E','F')) { throw "Board reported error: $line" }
            if ($line) { $unexpected += $line }
        } catch [System.TimeoutException] { }
    }
    $other = ($unexpected -join ', ')
    throw "ACK timeout after $WaitMs ms for '$Command'; other lines: $other. Confirm LAB-02 bitstream (not old PICO firmware), port name and cable."
}
try {
    Write-Host "Connecting to $PortName (115200 8N1), no extra USB-TTL adapter..."
    $sp.Open()
    Start-Sleep -Milliseconds 250
    $tests = @(
        @('0','L=0'),
        @('1','L=1'),
        @('4','L=4'),
        @('?','L=4'),
        @('6','L=6'),
        @('0','L=0')
    )
    foreach ($test in $tests) {
        $line = Invoke-DeviceCommand -Port $sp -Command $test[0] -WaitMs $TimeoutMs
        if ($line -ne $test[1]) {
            throw "Mismatch for '$($test[0])': received '$line', wanted '$($test[1])'"
        }
        Write-Host "  '$($test[0])' -> $line  [PASS]"
    }
    Write-Host 'LAB02_SERIAL_ACK_PASS: commands and MMIO readback. Confirm visual LEDs manually.'
} finally {
    if ($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}
