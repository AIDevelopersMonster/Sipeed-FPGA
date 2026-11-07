# PiKoSoL LAB-20.6 Windows uploader. Loads ONLY SDRAM; never writes FPGA Flash.
# Without -Upload, reports instructions and does not connect to COM or change hardware.
# -Upload opens the exclusive COM port, loads/reads back all words, and leaves BIOS prompt.
# -Upload -Boot additionally transfers control and REQUIRES physical RESET to return to BIOS.
[CmdletBinding()]
param(
  [string]$PortName = 'COM25',
  [switch]$Upload,
  [switch]$Boot,
  [int]$TimeoutMs = 7000
)
$ErrorActionPreference = 'Stop'
$ImageFile = Join-Path $PSScriptRoot 'snapshot.bin'
$ManifestFile = Join-Path $PSScriptRoot 'manifest.json'
$Image = [System.IO.File]::ReadAllBytes($ImageFile)
$Manifest = Get-Content -LiteralPath $ManifestFile -Raw | ConvertFrom-Json
$ActualHash = (Get-FileHash -LiteralPath $ImageFile -Algorithm SHA256).Hash.ToLowerInvariant()
if ($ActualHash -ne $Manifest.bin_sha256.ToLowerInvariant()) { throw "Image SHA256 mismatch: $ActualHash" }
if ($Image.Length -ne [int]$Manifest.image_bytes -or $Image.Length % 4 -ne 0) { throw 'Unexpected image size' }
if ($Image.Length -ge 4096) { throw 'Image overlaps snapshot scratch region' }
if (-not [BitConverter]::IsLittleEndian) { throw 'Expected little-endian Windows host' }
$LoadAddress = 0x40010000L
if ($Boot -and (-not $Upload)) { throw 'To boot, use explicit -Upload -Boot. This command does not return to BIOS.' }
Write-Host "PiKoSoL LAB-20.6: $($Image.Length) bytes, $($Image.Length / 4) words, SHA256 $ActualHash"
if (-not $Upload) {
  Write-Host "DRY RUN ONLY: no COM operation, no writes, no boot."
  Write-Host "Close any other terminal connected to $PortName, then run:"
  Write-Host "  pwsh -NoProfile -File .\upload.ps1 -PortName $PortName -Upload"
  Write-Host "After verification, boot in LiteX monitor: boot 0x40010000"
  Write-Host "Or explicitly upload+boot in PowerShell: pwsh -NoProfile -File .\upload.ps1 -PortName $PortName -Upload -Boot"
  Write-Host 'ATTENTION: boot never returns to the factory shell; use the physical RESET button afterwards.'
  return
}

Add-Type -AssemblyName System.IO.Ports -ErrorAction SilentlyContinue
$Port = [System.IO.Ports.SerialPort]::new($PortName,115200,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
$Port.Handshake = [System.IO.Ports.Handshake]::None
$Port.ReadTimeout = $TimeoutMs
$Port.WriteTimeout = $TimeoutMs
function Read-Until([string]$Needle, [int]$Timeout = 7000) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $b = New-Object System.Text.StringBuilder
  while ($sw.ElapsedMilliseconds -lt $Timeout) {
    $part = $Port.ReadExisting()
    if ($part.Length -gt 0) { [void]$b.Append($part) }
    if ($b.ToString().Contains($Needle)) { return $b.ToString() }
    Start-Sleep -Milliseconds 8
  }
  throw "TIMEOUT waiting for [$Needle]. Received: $($b.ToString())"
}
function Invoke-Bios([string]$Command) {
  $Port.DiscardInBuffer()
  $Port.Write($Command + "`r")
  return Read-Until 'litex>' $TimeoutMs
}
function Verify-Chunk([int]$Offset, [int]$Length) {
  $addr = $LoadAddress + [long]$Offset
  $dump = Invoke-Bios ('mem_read 0x{0:X8} {1}' -f $addr, $Length)
  $start = ('0x{0:x8}' -f $addr)
  $rx = '(?im)^' + [regex]::Escape($start) + '\s{2,}((?:[0-9a-f]{2}\s+){' + $Length + '})'
  $m = [regex]::Match($dump, $rx, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $m.Success) { throw "Cannot parse SDRAM readback $start : $dump" }
  $hex = @([regex]::Matches($m.Groups[1].Value, '[0-9a-fA-F]{2}') | ForEach-Object { $_.Value })
  if ($hex.Count -ne $Length) { throw "Invalid number of bytes at $start" }
  for($i=0;$i -lt $Length;$i++) {
    $got = [Convert]::ToByte($hex[$i],16)
    if($got -ne $Image[$Offset+$i]) { throw ('READBACK MISMATCH at 0x{0:X8}: expected {1:X2}, got {2:X2}' -f ($addr+$i), $Image[$Offset+$i], $got) }
  }
}
try {
  $Port.Open()
  $Port.DiscardInBuffer()
  $Port.Write("`r")
  [void](Read-Until 'litex>' $TimeoutMs)
  Write-Host 'BIOS prompt detected. Loading verified SDRAM payload...'
  for ($offset=0; $offset -lt $Image.Length; $offset += 4) {
    $word = [BitConverter]::ToUInt32($Image, $offset)
    $addr = $LoadAddress + [long]$offset
    $cmd = 'mem_write 0x{0:X8} 0x{1:X8}' -f $addr, $word
    $response = Invoke-Bios $cmd
    if ($response -match 'Incorrect|Unknown command') { throw "BIOS rejected $cmd : $response" }
    if ((($offset / 4) % 32) -eq 0) { Write-Host ('Written word {0}/{1}' -f (1+$offset/4), ($Image.Length/4)) }
  }
  Write-Host 'All words sent. Full readback, 16-byte blocks...'
  for ($offset=0; $offset -lt $Image.Length; $offset += 16) {
    Verify-Chunk $offset ([Math]::Min(16, $Image.Length-$offset))
  }
  Write-Host "PASS: $($Image.Length) bytes SDRAM load/readback verified against SHA256-controlled binary."
  if ($Boot) {
    Write-Host 'STARTING NOW: no automatic return to LiteX BIOS. Hardware RESET restores the BIOS.'
    $Port.DiscardInBuffer()
    $Port.Write('boot 0x40010000' + "`r")
    $result = Read-Until 'LAB20.6 HOLD - press physical RESET to return to BIOS' 20000
    Start-Sleep -Milliseconds 250
    $result += $Port.ReadExisting()
    Write-Host $result
    Write-Host 'Program launched; press hardware RESET to return to factory BIOS.'
  } else {
    Write-Host 'Payload loaded; BIOS remains active. To run, open console and issue: boot 0x40010000'
  }
} finally {
  if ($Port.IsOpen) { $Port.Close() }
  $Port.Dispose()
}