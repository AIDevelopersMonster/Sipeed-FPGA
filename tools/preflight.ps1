# Read-only environment inspection; no downloads, drivers, or writes outside Project.
$ErrorActionPreference='Continue'
Write-Host 'Sipeed FPGA preflight (read-only)'
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
foreach ($name in @('git','gh','python','iverilog','vvp','yosys','nextpnr-himbaechel','gowin_pack','openFPGALoader','riscv-none-elf-gcc')) {
  $c=Get-Command $name -ErrorAction SilentlyContinue
  if ($null -eq $c) { Write-Host "MISSING: $name" }
  else { Write-Host "FOUND: $name => $($c.Source)" }
}
$root = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education'
$gw = Join-Path $root 'IDE\bin\gw_sh.exe'
Write-Host "Gowin gw_sh.exe available at recorded location: $(Test-Path $gw)"
Write-Host 'Preflight does not prove hardware connectivity or compiler functionality.'
