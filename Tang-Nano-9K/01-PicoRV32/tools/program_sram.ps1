# Explicit volatile SRAM programming only. This script never writes persistent Flash.
param([Parameter(Mandatory=$true)][string]$Bitstream)
$ErrorActionPreference='Stop'
if (-not (Test-Path -LiteralPath $Bitstream)) { throw "Missing bitstream $Bitstream" }
if (-not (Get-Command openFPGALoader -ErrorAction SilentlyContinue)) { throw 'openFPGALoader missing from PATH' }
& openFPGALoader -b tangnano9k $Bitstream
if ($LASTEXITCODE -ne 0) { throw 'Programming failed.' }
Write-Host 'SRAM programming command returned success. Verify board behavior separately.'
