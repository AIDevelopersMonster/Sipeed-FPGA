# PiKoSoL LAB-04.3 v0.1.7 hardware acceptance AFTER independent Gowin STA.
# UART/ASCII only. NEVER triggers JTAG, Flash, Gowin build, or ROM writes.
[CmdletBinding()]
param([string]$PortName='COM10',[int]$TimeoutMs=4000,[switch]$NoVisualPrompts)
$ErrorActionPreference='Stop'
$sp = [System.IO.Ports.SerialPort]::new(
    $PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$sp.Handshake=[System.IO.Ports.Handshake]::None
$sp.DtrEnable=$false
$sp.RtsEnable=$false
$sp.ReadTimeout=250
$sp.WriteTimeout=1000
function Invoke-Command([string]$Cmd,[string]$MustInclude) {
    $sp.DiscardInBuffer()
    $sp.Write($Cmd)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $result=''
    while($sw.ElapsedMilliseconds -lt $TimeoutMs) {
        $result += $sp.ReadExisting()
        if($result.EndsWith('> ') -and $result.Contains($MustInclude)) {
            Write-Host "  [$Cmd] $MustInclude PASS"
            return $result
        }
        Start-Sleep -Milliseconds 25
    }
    throw "TIMEOUT cmd=$Cmd expected=$MustInclude received=$result"
}
function Confirm-Video([string]$State) {
    if($NoVisualPrompts) { return }
    $answer=Read-Host "HDMI: $State ; physical LEDs still respond? (y/n)"
    if($answer -ne 'y') { throw 'MANUAL VIDEO CHECK NOT PASSED' }
}
try {
    $sp.Open()
    Start-Sleep -Milliseconds 150
    Write-Host "LAB04_V017_UART_TEST $PortName 115200 8N1"
    $null=Invoke-Command '0' 'C=0'
    $null=Invoke-Command '?' 'M=00'
    $null=Invoke-Command '1' 'C=1'
    $null=Invoke-Command '?' 'M=01'
    Confirm-Video 'LED1 and first lower-screen HUD cell ON'
    $null=Invoke-Command 'A' 'V'
    $null=Invoke-Command 'l' 'V'
    $null=Invoke-Command 'G' 'V'
    $panel=Invoke-Command 'p' '| OBJ=A X=0A8'
    if($panel -notmatch '\+---------------------\+') { throw 'ASCII panel frame missing' }
    Write-Host $panel
    Confirm-Video 'object A moves right by 8 px and becomes green; ASCII panel visible'
    $null=Invoke-Command 'B' 'V'
    $null=Invoke-Command 'j' 'V'
    $null=Invoke-Command 'R' 'V'
    $panel=Invoke-Command 'p' '| OBJ=B X=17E'
    Write-Host $panel
    Confirm-Video 'object B moves left by 8 px and becomes red'
    $null=Invoke-Command '6' 'C=6'
    $null=Invoke-Command '?' 'M=3F'
    Confirm-Video 'all six LED HUD rectangles on; two sprites still visible'
    $null=Invoke-Command '0' 'C=0'
    $null=Invoke-Command '?' 'M=00'
    Write-Host 'LAB04_V017_UART_MMIO_ASCII_PASS: check for terminal parity and selected objects.'
    if($NoVisualPrompts) {
        Write-Host 'LAB04_V017_VISUAL_PENDING: manual HDMI/LED acceptance NOT performed.'
    } else {
        Write-Host 'LAB04_V017_MANUAL_VIDEO_PASS: user confirmed 4 visual checkpoints.'
    }
} finally {
    if($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}
