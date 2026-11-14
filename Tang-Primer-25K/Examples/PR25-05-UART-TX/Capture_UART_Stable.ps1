# PR25-05: compare actual received beacon intervals with RTL period.
# Receiver only; no FPGA/BL616 firmware modification, no port switching.
param(
    [string]$Port = 'COM25',
    [int]$Baud = 9600,
    [int]$Seconds = 10,
    [int]$SettleMs = 1000
)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$expected = [System.Text.Encoding]::ASCII.GetBytes("PR25 UART TX TEST`r`n")
$all = @([System.IO.Ports.SerialPort]::GetPortNames())
if ($Port -notin $all) { throw "Missing $Port. Available: $($all -join ', ')" }
$sp = [System.IO.Ports.SerialPort]::new(
    $Port, $Baud, [System.IO.Ports.Parity]::None,
    8, [System.IO.Ports.StopBits]::One)
$sp.Handshake = [System.IO.Ports.Handshake]::None
$sp.DtrEnable = $false
$sp.RtsEnable = $false
$sp.ReadTimeout = 500
$raw = [System.Collections.Generic.List[byte]]::new()
$pending = [System.Collections.Generic.List[byte]]::new()
$frameTimes = [System.Collections.Generic.List[double]]::new()
$noise = 0
try {
    $sp.Open()
    Start-Sleep -Milliseconds $SettleMs
    $before = $sp.BytesToRead
    $sp.DiscardInBuffer()
    Write-Host "UART CONTROL $Port $Baud/8N1; discarded $before queued bytes after $SettleMs ms"
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    while ($timer.Elapsed.TotalSeconds -lt $Seconds) {
        $n = $sp.BytesToRead
        if ($n -le 0) { Start-Sleep -Milliseconds 10; continue }
        $buffer = [byte[]]::new($n)
        $got = $sp.Read($buffer, 0, $n)
        for ($i=0; $i -lt $got; $i++) {
            $v = $buffer[$i]
            $raw.Add($v)
            $pending.Add($v)
            if ($pending.Count -ge $expected.Length) {
                $matched = $true
                for ($j = 0; $j -lt $expected.Length; $j++) {
                    if ($pending[$j] -ne $expected[$j]) { $matched = $false; break }
                }
                if ($matched) {
                    $frameTimes.Add($timer.Elapsed.TotalSeconds)
                    $pending.Clear()
                } else {
                    $pending.RemoveAt(0)
                    $noise++
                }
            }
        }
    }
    $noise += $pending.Count
    Write-Host "TOTAL_BYTES: $($raw.Count)"
    Write-Host "EXACT_FRAMES: $($frameTimes.Count)"
    Write-Host "UNMATCHED_BYTES: $noise"
    if ($frameTimes.Count -gt 0) {
        Write-Host ("FRAME_TIMES_SEC: " + (($frameTimes | ForEach-Object { [math]::Round($_,3) }) -join ', '))
        if ($frameTimes.Count -gt 1) {
            $deltas = @(
                for ($i=1; $i -lt $frameTimes.Count; $i++) {
                    [math]::Round($frameTimes[$i] - $frameTimes[$i-1], 3)
                }
            )
            Write-Host ("INTERVALS_SEC: " + ($deltas -join ', '))
        }
    }
    if ($raw.Count -gt 0) {
        $n = [math]::Min(64, $raw.Count)
        $first = [byte[]]::new($n)
        for($i=0; $i -lt $n; $i++) { $first[$i] = $raw[$i] }
        Write-Host ("FIRST_HEX: " + [Convert]::ToHexString($first))
    }
    if ($noise -eq 0 -and $frameTimes.Count -ge 10) {
        Write-Host 'BYTE_INTEGRITY: PASS for captured frames; verify measured intervals independently'
    } elseif ($raw.Count -eq 0) {
        Write-Host 'BYTE_INTEGRITY: NO DATA'
    } else {
        Write-Host 'BYTE_INTEGRITY: MIXED / INCOMPLETE'
    }
} finally {
    if ($sp.IsOpen) { $sp.Close() }
    $sp.Dispose()
}
