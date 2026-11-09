# EX20-05 local LiteX/VexRiscv+HDMI gateware generation/build.
# No JTAG, no SRAM programming, no Flash programming.
[CmdletBinding()]
param(
    [string]$Python = 'C:\GitHub\litex-b05c3069-test\venv\Scripts\python.exe',
    [string]$GowinRoot = 'C:\Gowin\Gowin_V1.9.9Beta-4_Education',
    [switch]$Build
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    throw "Python not found: $Python. Supply -Python with the LiteX Python executable."
}
$src = Join-Path $PSScriptRoot 'build_soc.py'
$rtl = Join-Path $PSScriptRoot 'rtl\video_hdmi_bridge.v'
$ip = Join-Path $PSScriptRoot 'vendor\dvi_tx.v'
if (!(Test-Path $src) -or !(Test-Path $rtl) -or !(Test-Path $ip)) {
    throw 'Missing integration sources or vendor IP. First run prepare_vendor.ps1.'
}
# Confirm that the selected Python environment contains real LiteX and board packages.
& $Python -c "import litex, litedram, litex_boards, migen; print('PYTHON_LITEX_IMPORT_PASS')"
if ($LASTEXITCODE -ne 0) { throw 'Python environment does not contain LiteX/litedram/boards/migen.' }
$ideBin = Join-Path $GowinRoot 'IDE\bin'
if ($Build) {
    if (-not (Test-Path -LiteralPath $ideBin -PathType Container)) {
        throw "Gowin IDE/bin missing: $ideBin"
    }
    $env:PATH = "$ideBin;$env:PATH"
}
New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'evidence') -Force | Out-Null
$log = Join-Path $PSScriptRoot ('evidence\INTEGRATED_SOC_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
$argsList = @($src)
if ($Build) { $argsList += '--build' }
Write-Host ('RUN: ' + $Python + ' ' + ($argsList -join ' '))
& $Python @argsList 2>&1 | Tee-Object -FilePath $log
$code = $LASTEXITCODE
Write-Host "BUILD LOG: $log"
if ($code -ne 0) { throw "LiteX/Gowin failed exit $code; NO FPGA operation performed." }
if ($Build) {
    Write-Host 'Gowin tool returned exit 0; inspect PNR/STA and output .fs before any SRAM test.'
} else {
    Write-Host 'LiteX generator returned exit 0. Run with -Build to request Gowin synthesis.'
}
Write-Host 'NO JTAG / NO FLASH / NO FPGA WRITES'
