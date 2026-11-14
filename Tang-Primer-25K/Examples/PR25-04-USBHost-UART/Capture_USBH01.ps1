# PR25-04 USBH01 - OPEN UART FIRST, program FPGA SRAM, capture RISC-V/USB diagnostics.
# Windows PowerShell 7. Only programs FPGA SRAM (--run 2). Does not write FPGA Flash.
param(
    [string]$Port = 'COM25',
    [int]$Baud = 115200,
    [int]$Seconds = 25,
    [string]$FsFile = 'C:\GitHub\TangPrimer25K_USBHost_UART\impl\pnr\usb_keyboard_uart.fs',
    [string]$GowinRoot = 'C:\Gowin',
    [int]$CableIndex = 1
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$expected='6DDBBBEF60EF65789687F9A9B5AF710F23899F0F5996DC1AA1B8DDDAD2A52036'
if (!(Test-Path -LiteralPath $FsFile)) { throw "Missing bitstream: $FsFile" }
$hash=(Get-FileHash -LiteralPath $FsFile -Algorithm SHA256).Hash
if ($hash -ne $expected) { throw "Unexpected USBH01 bitstream SHA256: $hash" }
$cli=@(Get-ChildItem -Path $GowinRoot -File -Recurse -Filter 'programmer_cli.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1)
if (!$cli) { throw 'Gowin programmer_cli.exe not found' }
if ($Port -notin [System.IO.Ports.SerialPort]::GetPortNames()) {
    throw "Port $Port is not available. Check Windows device list."
}
$evidence=Join-Path (Split-Path $FsFile -Parent | Split-Path -Parent | Split-Path -Parent) 'evidence'
New-Item -Path $evidence -ItemType Directory -Force | Out-Null
$stamp=Get-Date -Format 'yyyyMMdd_HHmmss'
$outFile=Join-Path $evidence ("USBH01_UART_$stamp.bin")
$textFile=Join-Path $evidence ("USBH01_UART_$stamp.txt")
$progLog=Join-Path $evidence ("USBH01_PROGRAM_$stamp.log")
$progErr=Join-Path $evidence ("USBH01_PROGRAM_$stamp.err.log")
Write-Host "USBH01: $FsFile"
Write-Host "SHA256 verified: $hash"
Write-Host "SERIAL: $Port @ $Baud 8N1, handshake NONE"
Write-Host "CAPTURE: $Seconds seconds; open UART BEFORE SRAM program"
Write-Host "PROGRAM: FPGA SRAM (--run 2); no Flash writes"
Write-Host "Connect a wired USB keyboard to the Dock's USB-A before running."
$sp=$null
$proc=$null
$bytes=[System.Collections.Generic.List[byte]]::new()
try {
    $sp=[System.IO.Ports.SerialPort]::new($Port,$Baud,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
    $sp.Handshake=[System.IO.Ports.Handshake]::None
    $sp.DtrEnable=$false
    $sp.RtsEnable=$false
    $sp.ReadTimeout=250
    $sp.Open()
    Start-Sleep -Milliseconds 400
    $sp.DiscardInBuffer() # discard stale data from prior baud-switching test
    Write-Host "UART open; launching Gowin SRAM programming..."
    $args=@('--device','GW5A-25A','--run','2','--fsFile', $FsFile,'--cable-index',"$CableIndex")
    $proc=Start-Process -FilePath $cli[0].FullName -ArgumentList $args -PassThru -RedirectStandardOutput $progLog -RedirectStandardError $progErr
    $clock=[System.Diagnostics.Stopwatch]::StartNew()
    while ($clock.Elapsed.TotalSeconds -lt $Seconds) {
        $n=$sp.BytesToRead
        if ($n -gt 0) {
            $block=[byte[]]::new([Math]::Min($n,16384))
            $read=$sp.Read($block,0,$block.Length)
            for($i=0;$i -lt $read;$i++){$bytes.Add($block[$i])}
        } else {
            Start-Sleep -Milliseconds 25
        }
    }
    if (-not $proc.HasExited) {
        if (-not $proc.WaitForExit(15000)) { throw "Programmer still active; inspect process/log: $progLog" }
    }
    $proc.Refresh()
    Write-Host "SRAM PROGRAM EXIT: $($proc.ExitCode)"
    if (Test-Path $progLog) {
        Write-Host 'PROGRAMMER OUTPUT:'
        Get-Content -Path $progLog -Tail 12 | ForEach-Object { Write-Host $_ }
    }
} finally {
    if ($null -ne $sp) {
        try { if ($sp.IsOpen) { $sp.Close() } } catch {}
        $sp.Dispose()
    }
    if ($null -ne $proc) { $proc.Dispose() }
    $data=$bytes.ToArray()
    [System.IO.File]::WriteAllBytes($outFile,$data)
    $visible=[System.Text.Encoding]::ASCII.GetString($data)
    [System.IO.File]::WriteAllText($textFile,$visible,[System.Text.UTF8Encoding]::new($false))
    Write-Host "UART CAPTURE: $($data.Length) bytes"
    Write-Host "BIN: $outFile"
    Write-Host "TEXT: $textFile"
    if ($data.Length -gt 0) {
        $n=[Math]::Min(256,$data.Length)
        Write-Host ('HEX FIRST BYTES: '+[Convert]::ToHexString($data[0..($n-1)]))
        $clip= if ($visible.Length -gt 4096) { $visible.Substring(0,4096) } else { $visible }
        Write-Host 'ASCII FIRST 4096 CHARS:'
        Write-Host $clip
    }
}
