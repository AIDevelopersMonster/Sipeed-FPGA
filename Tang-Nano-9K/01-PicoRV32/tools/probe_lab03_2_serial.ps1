# LAB-03.2 physical probe. Run only AFTER RTL + Gowin PnR/STA PASS and SRAM load + S2.
# Opens the selected COM port exclusively and ALWAYS closes it in finally.
param(
    [string]$PortName='COM10',
    [switch]$CaptureNew,
    [ValidateRange(0,6)][int]$Led=4,
    [ValidateRange(2500,60000)][int]$TimeoutMs=20000,
    [string]$OutputPath=''
)
$ErrorActionPreference='Stop'
$base=Split-Path -Parent $PSScriptRoot
$serial=[System.IO.Ports.SerialPort]::new($PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$serial.Handshake=[System.IO.Ports.Handshake]::None
$serial.DtrEnable=$false
$serial.RtsEnable=$false
$serial.NewLine="`n"
$serial.ReadTimeout=200
$serial.WriteTimeout=1500
$clock=[System.Diagnostics.Stopwatch]::StartNew()
$lines=[System.Collections.Generic.List[string]]::new()

function Read-Line-BeforeDeadline {
    param([System.IO.Ports.SerialPort]$Port,[System.Diagnostics.Stopwatch]$Clock,[int]$Deadline)
    while ($Clock.ElapsedMilliseconds -lt $Deadline) {
        try {
            $v=$Port.ReadLine().TrimEnd([char]13)
            if ($v -eq 'READY') { continue }
            return $v
        } catch [System.TimeoutException] { }
    }
    throw "LAB03_2: UART timeout after $Deadline ms; check bitstream, S2 reset, COM and 115200 8N1."
}

try {
    Write-Host "Opening $PortName at 115200 8N1; close old HTML tabs and serial terminals first."
    $serial.Open()
    Start-Sleep -Milliseconds 250
    $serial.DiscardInBuffer()
    if ($CaptureNew) {
        $serial.Write('C')
        $line=Read-Line-BeforeDeadline $serial $clock $TimeoutMs
        if ($line -ne 'C') { throw "LAB03_2: C ACK expected, got '$line'" }
        $serial.Write([string]$Led)
        $line=Read-Line-BeforeDeadline $serial $clock $TimeoutMs
        if ($line -ne "L=$Led") { throw "LAB03_2: LED ACK expected L=$Led; got '$line'" }
        Write-Host "New snapshot for LED L$Led requested (0 means all OFF)."
    }
    $serial.Write('T')
    $header=Read-Line-BeforeDeadline $serial $clock $TimeoutMs
    if ($header -notmatch '^T3:[0-9a-fA-F]{8}:[0-9a-fA-F]{8}$') {
        throw "LAB03_2: T3 header not received (got '$header'); confirm LAB-03.2 firmware, not LAB-02."
    }
    $lines.Add($header)
    $n=0
    while ($true) {
        $line=Read-Line-BeforeDeadline $serial $clock $TimeoutMs
        if ($line -eq 'Z') { $lines.Add('Z');break }
        if ($line -notmatch '^E:[0-9a-fA-F]{8}:[0-9a-fA-F]{8}:[0-9a-fA-F]{8}:[0-9a-fA-F]{8}$') {
            throw "LAB03_2: malformed event: '$line'"
        }
        $lines.Add($line)
        $n++
        if ($n>128) { throw 'LAB03_2: snapshot has more than 128 events' }
    }
} finally {
    if ($serial.IsOpen) { $serial.Close() }
    $serial.Dispose()
}
if (-not $OutputPath) {
    $OutputPath=Join-Path $base ('build\lab03_2_board_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
}
$fullOut=[System.IO.Path]::GetFullPath($OutputPath)
$folder=Split-Path -Parent $fullOut
if (-not (Test-Path $folder)) { New-Item -ItemType Directory -Force -Path $folder | Out-Null }
[System.IO.File]::WriteAllLines($fullOut,$lines,[System.Text.UTF8Encoding]::new($false))
Write-Host "UART dump saved: $fullOut"
& python (Join-Path $base 'tools\lab03_trace_decode.py') $fullOut
if ($LASTEXITCODE -ne 0) { throw 'LAB03_2: capture decode or ROM cross-check failed' }
Write-Host 'LAB03_2_BOARD_UART_DATA_PASS: transport and ROM-verified snapshot; LED optical observation requires operator.'
