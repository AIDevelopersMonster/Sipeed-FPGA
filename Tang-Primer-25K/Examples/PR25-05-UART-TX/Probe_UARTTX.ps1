# PR25-05: passive read-only serial port probe. No terminal responses are expected.
# Close PuTTY/Tera Term/etc. before running. The FPGA sends a periodic beacon.
param(
    [string[]]$Ports = @('COM24','COM25'),
    [int[]]$Bauds = @(115200,460800),
    [int]$Seconds = 5
)
$ErrorActionPreference = 'Continue'
$all = @([System.IO.Ports.SerialPort]::GetPortNames() | Sort-Object)
Write-Host "Available COM ports: $($all -join ', ')"
foreach ($portName in $Ports) {
    foreach ($rate in $Bauds) {
        if ($portName -notin $all) { Write-Host "$portName is not present"; continue }
        $sp = $null
        Write-Host "---- $portName @ $rate baud, 8N1, flow=None ($Seconds seconds) ----"
        try {
            $sp = [System.IO.Ports.SerialPort]::new(
                $portName, $rate, [System.IO.Ports.Parity]::None,
                8, [System.IO.Ports.StopBits]::One)
            $sp.Handshake = [System.IO.Ports.Handshake]::None
            $sp.ReadTimeout = 250
            $sp.DtrEnable = $false
            $sp.RtsEnable = $false
            $sp.Open()
            $bytes = [System.Collections.Generic.List[byte]]::new()
            $clock = [System.Diagnostics.Stopwatch]::StartNew()
            while ($clock.Elapsed.TotalSeconds -lt $Seconds) {
                $waiting = $sp.BytesToRead
                if ($waiting -gt 0) {
                    $buffer = [byte[]]::new($waiting)
                    $count = $sp.Read($buffer,0,$waiting)
                    for ($i=0; $i -lt $count; $i++) { $bytes.Add($buffer[$i]) }
                } else {
                    Start-Sleep -Milliseconds 50
                }
            }
            if ($bytes.Count -eq 0) {
                Write-Host 'RESULT: no received bytes'
            } else {
                Write-Host "RESULT: $($bytes.Count) bytes"
                $sample = $bytes.ToArray()
                Write-Host ('HEX: ' + [Convert]::ToHexString($sample))
                Write-Host ('ASCII: ' + [System.Text.Encoding]::ASCII.GetString($sample))
            }
        } catch {
            Write-Host "OPEN/READ ERROR: $($_.Exception.Message)"
        } finally {
            if ($null -ne $sp) { if ($sp.IsOpen) { $sp.Close() }; $sp.Dispose() }
        }
    }
}
