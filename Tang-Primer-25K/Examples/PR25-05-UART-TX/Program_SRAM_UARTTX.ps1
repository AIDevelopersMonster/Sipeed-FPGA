# PR25-05 - check FS then program *SRAM only* (never onboard Flash).
param(
    [string]$File = 'C:\GitHub\TangPrimer25K_UART_TX\impl\pnr\pr25_uart_tx.fs',
    [string]$GowinRoot = 'C:\Gowin',
    [int]$CableIndex = 1
)
$ErrorActionPreference='Stop'
if (!(Test-Path -LiteralPath $File)) { throw "Missing: $File" }
$cli = @(Get-ChildItem -Path $GowinRoot -Recurse -File -Filter 'programmer_cli.exe' -ErrorAction SilentlyContinue |
    Sort-Object FullName -Descending | Select-Object -First 1)
if (!$cli) { throw 'programmer_cli.exe not found' }
Write-Host "FS: $File"
Write-Host "SHA256: $((Get-FileHash -Path $File -Algorithm SHA256).Hash)"
Write-Host "PROGRAM: GW5A-25A SRAM (--run 2), CABLE: $CableIndex"
& $cli[0].FullName --device GW5A-25A --run 2 --fsFile $File --cable-index $CableIndex
$code=$LASTEXITCODE
Write-Host "SRAM PROGRAM EXIT: $code"
if ($code -ne 0) { throw 'Programming failed' }
