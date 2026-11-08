# Tang Nano 20K LiteX closeout: read-only, BIOS COM, no Flash writes.
[CmdletBinding()]
param([string]$PortName='COM25',[int]$TimeoutMs=7000)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
$p=[System.IO.Ports.SerialPort]::new($PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$p.Handshake=[System.IO.Ports.Handshake]::None
$p.ReadTimeout=$TimeoutMs
$p.WriteTimeout=$TimeoutMs
$log=[System.Collections.Generic.List[string]]::new()
function Strip-Ansi([string]$s) { return [regex]::Replace($s,'\x1B\[[0-?]*[ -/]*[@-~]','') }
function Bios([string]$command) {
 $p.DiscardInBuffer()
 $p.Write($command+[char]13)
 $sw=[System.Diagnostics.Stopwatch]::StartNew()
 $buf=[System.Text.StringBuilder]::new()
 while($sw.ElapsedMilliseconds -lt $TimeoutMs) {
  $part=$p.ReadExisting()
  if($part.Length -gt 0) {
   [void]$buf.Append($part)
   $plain=Strip-Ansi $buf.ToString()
   if($plain.Contains('litex>')) {
    $log.Add("COMMAND: $command")
    $log.Add($plain)
    if($plain -match '(?i)unknown command|incorrect argument'){throw "BIOS rejected [$command]: $plain"}
    return $plain
   }
  }
  Start-Sleep -Milliseconds 10
 }
 throw "TIMEOUT waiting for BIOS after [$command]: $(Strip-Ansi $buf.ToString())"
}
function Read32([uint64]$addr) {
 $a='0x{0:X8}' -f $addr
 $response=Bios "mem_read $a 4"
 $marker=$response.IndexOf('Memory dump:',[System.StringComparison]::OrdinalIgnoreCase)
 if($marker -lt 0){throw "Memory dump missing at $a"}
 $body=$response.Substring($marker+12)
 $pattern='(?i)'+[regex]::Escape($a)+'[ \t]{2,}((?:[0-9a-f]{2}[ \t]+){4})'
 $m=[regex]::Match($body,$pattern)
 if(-not $m.Success){throw "Cannot parse $a : $body"}
 $bytes=@([regex]::Matches($m.Groups[1].Value,'(?i)[0-9a-f]{2}') | ForEach-Object {[Convert]::ToByte($_.Value,16)})
 if($bytes.Count -ne 4){throw "Invalid byte count at $a"}
 return [BitConverter]::ToUInt32([byte[]]$bytes,0)
}
try {
 $p.Open()
 $null=Bios ''
 Write-Host 'PASS BIOS prompt and COM link'
 $map=Bios 'mem_list'
 Write-Host 'PASS mem_list retrieved (inspect log for timer presence)'
 foreach($off in @(4,8,12,16,20,24,28)){
  $addr=0xF0003000UL+[uint64]$off
  $v=Read32 $addr
  Write-Host ('UART 0x{0:X8} = 0x{1:X8}' -f $addr,$v)
 }
 Write-Host 'PASS UART status CSR seven read-only samples'
 Write-Host 'NO RAM WRITES / NO IRQ ENABLE / NO BOOT / NO FLASH WRITES'
} finally {
 if($p.IsOpen){$p.Close()}
 $p.Dispose()
 $dir=Join-Path $PSScriptRoot 'evidence'
 New-Item -ItemType Directory -Path $dir -Force | Out-Null
 $file=Join-Path $dir ('BIOS_READONLY_'+(Get-Date -Format 'yyyyMMdd_HHmmss')+'.txt')
 [IO.File]::WriteAllLines($file,$log.ToArray())
 Write-Host "Evidence saved: $file"
}
