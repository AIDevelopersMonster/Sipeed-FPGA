# Tang Primer 25K UART bridge recovery (Windows PowerShell 7).
# Default INSPECT. No FPGA Flash or BL616 firmware operations.
# Purge: locally clear/drain serial driver queue, not a BL616 silicon reset.
# RestartVCP: explicitly restart only the named COM PnP device (admin).
param(
  [ValidateSet('Inspect','Purge','RestartVCP')] [string]$Mode='Inspect',
  [string]$Port='COM25', [int]$Baud=9600, [int]$DrainSeconds=3
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version Latest
$pnp=@(Get-PnpDevice -PresentOnly | Where-Object {
  $_.FriendlyName -match ('\(' + [regex]::Escape($Port) + '\)')
})
Write-Host "TARGET PORT: $Port"
foreach($p in $pnp){Write-Host "PNP: $($p.FriendlyName) ID=$($p.InstanceId)"}
if($Mode -eq 'Inspect'){
  Write-Host 'Inspect only. -Mode Purge drains/clears COM data; -Mode RestartVCP requests PnP driver restart.'
  return
}
if($Mode -eq 'Purge'){
  $sp=[System.IO.Ports.SerialPort]::new($Port,$Baud,[System.IO.Ports.Parity]::None,8,[System.IO.Ports.StopBits]::One)
  $sp.Handshake=[System.IO.Ports.Handshake]::None
  $sp.DtrEnable=$false
  $sp.RtsEnable=$false
  try{
    $sp.Open()
    Write-Host "COM open: $Port @ $Baud; bytes queued=$($sp.BytesToRead)"
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $drained=0
    while($sw.Elapsed.TotalSeconds -lt $DrainSeconds){
      $n=$sp.BytesToRead
      if($n -gt 0){
        $buf=[byte[]]::new($n)
        $drained += $sp.Read($buf,0,$n)
      }else{Start-Sleep -Milliseconds 25}
    }
    $sp.DiscardInBuffer()
    $sp.DiscardOutBuffer()
    Write-Host "PURGE COMPLETE: drained $drained bytes, Windows COM queues discarded"
    Write-Host 'Warning: BL616/USB internal queues may remain. No firmware reset performed.'
  }finally{
    if($sp.IsOpen){$sp.Close()}
    $sp.Dispose()
  }
  return
}
if($pnp.Count -ne 1){throw "Found $($pnp.Count) present PnP devices for $Port; need exactly one."}
$admin=([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $admin){throw 'Run PowerShell as Administrator for RestartVCP.'}
Write-Host "Restarting PnP VCP instance $($pnp[0].InstanceId) only."
& pnputil.exe /restart-device "$($pnp[0].InstanceId)"
if($LASTEXITCODE -ne 0){throw "pnputil failed with exit $LASTEXITCODE"}
Write-Host 'Restart complete at PnP level; BL616 hardware reset is NOT guaranteed.'
