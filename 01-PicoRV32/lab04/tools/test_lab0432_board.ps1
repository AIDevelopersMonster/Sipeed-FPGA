# LAB-04.3.2 board acceptance. NEVER programs FPGA or Flash.
# Run ONLY after clean Gowin PnR and check_sta_v018b.py PASS for this build.
[CmdletBinding()]
param(
    [string]$PortName='COM10',
    [int]$TimeoutMs=8000,
    [switch]$NoVisualPrompts
)
$ErrorActionPreference='Stop'
$sp=[System.IO.Ports.SerialPort]::new(
    $PortName,115200,[System.IO.Ports.Parity]::None,8,
    [System.IO.Ports.StopBits]::One)
$sp.Handshake=[System.IO.Ports.Handshake]::None
$sp.ReadTimeout=250
$sp.WriteTimeout=1000
$sp.DtrEnable=$false
$sp.RtsEnable=$false
function Invoke-ShellCommand([string]$Command,[string]$MustContain) {
    $sp.DiscardInBuffer()
    $sp.Write($Command+"`r")
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $reply=''
    while($clock.ElapsedMilliseconds -lt $TimeoutMs) {
        $reply+=$sp.ReadExisting()
        if($reply.Contains($MustContain) -and $reply.EndsWith('PiKoSoL> ')) {
            Write-Host "  [$Command] $MustContain PASS"
            return $reply
        }
        Start-Sleep -Milliseconds 25
    }
    throw "TIMEOUT [$Command] expected=$MustContain received=$reply"
}
function Confirm-HDMI([string]$Prompt) {
    if($NoVisualPrompts){return}
    $answer=Read-Host "HDMI CHECK: $Prompt (y/n)"
    if($answer -ne 'y'){throw "Visual checkpoint not confirmed: $Prompt"}
}
try {
    $sp.Open()
    Start-Sleep -Milliseconds 150
    Write-Host "LAB0432_BOARD_TEST $PortName 115200 8N1, no programming"
    $null=Invoke-ShellCommand 'HELP' 'HELP INFO MEM LED'
    $null=Invoke-ShellCommand 'INFO' 'PiKoSoL LAB-04.3.2'
    $null=Invoke-ShellCommand 'MEM' 'ROM 16KiB'
    Confirm-HDMI 'TERM mode: readable text history, no loose graphics blocks'
    $null=Invoke-ShellCommand 'LED 3' 'C=3'
    $null=Invoke-ShellCommand 'LED ?' 'M=07'
    Confirm-HDMI 'LED1..3 HUD are ON'
    $null=Invoke-ShellCommand 'GFX' 'MODE: GRAPHICS'
    Confirm-HDMI 'GFX shows A/B inside canvas; right status panel not obscured'
    $null=Invoke-ShellCommand 'OBJ B' 'V'
    $null=Invoke-ShellCommand 'MOVE J' 'V'
    $null=Invoke-ShellCommand 'COLOR G' 'V'
    Confirm-HDMI 'B moved left exactly one 8-pixel step and changed color'
    $null=Invoke-ShellCommand 'KEYS' 'LIVE KEYS'
    $sp.DiscardInBuffer()
    $sp.Write('jjjkkk') # raw graphics controls, no Enter
    Start-Sleep -Milliseconds 500
    Confirm-HDMI 'live KEYS: B moved left 24px and down 24px without Enter'
    $sp.Write('T')      # exits raw mode immediately, not line-buffered
    $clock=[Diagnostics.Stopwatch]::StartNew()
    $returnReply=''
    while($clock.ElapsedMilliseconds -lt $TimeoutMs) {
        $returnReply+=$sp.ReadExisting()
        if($returnReply.Contains('MODE: TERMINAL') -and $returnReply.EndsWith('PiKoSoL> ')) { break }
        Start-Sleep -Milliseconds 25
    }
    if(-not $returnReply.Contains('MODE: TERMINAL')) {
        throw "KEYS exit to TERM failed: $returnReply"
    }
    Write-Host '  [KEYS jjjkkk T] live move + terminal return PASS'
    Confirm-HDMI 'TERM restores text history and hides loose squares'
    $null=Invoke-ShellCommand 'LED 0' 'C=0'
    $null=Invoke-ShellCommand 'LED ?' 'M=00'
    Write-Host 'LAB0432_BOARD_UART_MMIO_PASS: string shell, two modes, LED and GFX commands'
    if($NoVisualPrompts){
        Write-Host 'LAB0432_VISUAL_PENDING: user did not confirm HDMI checkpoints'
    }else{
        Write-Host 'LAB0432_MANUAL_HDMI_PASS: user confirmed all 5 visual checkpoints'
    }
}finally{
    if($sp.IsOpen){$sp.Close()}
    $sp.Dispose()
}
