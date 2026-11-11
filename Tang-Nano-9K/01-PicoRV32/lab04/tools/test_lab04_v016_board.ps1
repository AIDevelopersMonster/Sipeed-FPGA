# LAB-04.2 v0.1.6 read/write UART test, board-only; NEVER touches JTAG/Flash.
# Requires the candidate bitstream already SRAM-programmed and COM closed elsewhere.
[CmdletBinding()]
param([string]$PortName='COM10', [int]$TimeoutMs=2500)
$ErrorActionPreference='Stop'
if ($TimeoutMs -lt 600) { throw 'TimeoutMs must be at least 600' }
$sp = [System.IO.Ports.SerialPort]::new(
    $PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$sp.Handshake = [System.IO.Ports.Handshake]::None
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sp.ReadTimeout = 250
$sp.WriteTimeout = 1000
$tests = @(
    @('0','C=0'),
    @('?','M=00'),
    @('1','C=1'),
    @('?','M=01'),
    @('f','L=6'),
    @('?','M=20'),
    @('6','C=6'),
    @('?','M=3F'),
    @('0','C=0'),
    @('?','M=00')
)
function Send-Test {
    param([System.IO.Ports.SerialPort]$Port,[string]$Command,[string]$Expected,[int]$DeadlineMs)
    $Port.DiscardInBuffer()
    $Port.Write($Command)
    $buffer = ''
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    while ($stopwatch.ElapsedMilliseconds -lt $DeadlineMs) {
        $buffer += $Port.ReadExisting()
        # The firmware prints an LF after each response and '> ' as a prompt.
        # Allow a leftover partial prompt to precede the expected response.
        if ($buffer.Contains($Expected + "`n") -or
            $buffer.Contains($Expected + "`r`n")) {
            Write-Host "  $Command -> $Expected [PASS]"
            return
        }
        if ($buffer -match '(^|\n)[EF]\r?\n') { throw "FPGA reported E/F for $Command : $buffer" }
        Start-Sleep -Milliseconds 20
    }
    throw "Timeout for '$Command' expecting '$Expected'; captured: $buffer"
}
try {
    Write-Host "LAB04_V016_BOARD_UART_TEST on $PortName (115200 8N1)"
    $sp.Open()
    Start-Sleep -Milliseconds 150
    foreach ($case in $tests) {
        Send-Test -Port $sp -Command $case[0] -Expected $case[1] -DeadlineMs $TimeoutMs
    }
    Write-Host 'LAB04_V016_UART_COMMAND_READBACK_PASS'
    Write-Host 'Visual HDMI/LED verification is still required: bars LED1..LED6, stable image.'
} finally {
    if ($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}
