# PR25-04 USBH01: Gowin CLI synthesis -> PNR -> bitstream (SRAM FLASH NOT touched).
# Requires Prepare_USBH01.ps1 PASS, Gowin IDE installed.
param(
    [string]$Work = "C:\GitHub\TangPrimer25K_USBHost_UART",
    [string]$GowinRoot = "C:\Gowin"
)
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if (!(Test-Path (Join-Path $Work 'usb_keyboard_uart.gprj'))) {
    throw "PREPARE NOT PASS: usb_keyboard_uart.gprj missing"
}
if (!(Test-Path (Join-Path $Work 'ucmem\mem.hex'))) {
    throw "MEMORY INIT MISSING: ucmem\mem.hex"
}
$inputFiles = @(
    'src/top.sv',
    'src/gowin/pll_usb.v',
    'src/usb_host/rv32i.v',
    'src/usb_host/usb11_phy.v',
    'src/usb_host/usb11_regs.v',
    'src/usb_host/usb11_sie.v',
    'src/usb_host/usb_host.v',
    'src/pins.cst',
    'src/timing.sdc'
)
foreach ($file in $inputFiles) {
    if (!(Test-Path (Join-Path $Work ($file.Replace('/', '\'))))) {
        throw "SOURCE MISSING: $file"
    }
}

$exe = @(Get-ChildItem -Path $GowinRoot -Filter 'gw_sh.exe' -File -Recurse -ErrorAction SilentlyContinue |
         Where-Object { $_.FullName -match 'IDE\\bin\\gw_sh\.exe$' } |
         Sort-Object FullName -Descending |
         Select-Object -First 1)
if ($exe.Count -eq 0) { throw "gw_sh.exe not found under $GowinRoot" }
$gwsh = $exe[0].FullName

# Use supported Tcl commands set_device, add_file, set_option and run all.
# There is no open_project/create_project, previously unsupported in this environment.
$lines = @(
    'set_device -name GW5A-25A GW5A-LV25MG121NES',
    'set_option -top_module top',
    'set_option -output_base_name usb_keyboard_uart',
    'set_option -verilog_std sysv2017',
    'set_option -use_cpu_as_gpio 1'
)
foreach ($file in $inputFiles) {
    $lines += "add_file $file"
}
$lines += 'run all'

$tcl = Join-Path $Work 'run_usb_keyboard_uart.tcl'
[System.IO.File]::WriteAllLines($tcl, $lines, [System.Text.UTF8Encoding]::new($false))

$evidence = Join-Path $Work 'evidence'
New-Item -ItemType Directory -Force -Path $evidence | Out-Null
$log = Join-Path $evidence ('USBH01_BUILD_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.log')
$before = [DateTime]::UtcNow
Write-Host "USBH01: Gowin CLI build"
Write-Host "EXE: $gwsh"
Write-Host "WORK: $Work"
Write-Host "TCL: $tcl"
Write-Host "LOG: $log"
Write-Host "NO FPGA WRITES"

$exitCode = -999
Push-Location $Work
try {
    & $gwsh $tcl 2>&1 | Tee-Object -FilePath $log
    $exitCode = $LASTEXITCODE
} finally {
    Pop-Location
}
Write-Host "GOWIN EXIT: $exitCode"

$fs = Join-Path $Work 'impl\pnr\usb_keyboard_uart.fs'
if ($exitCode -ne 0) {
    Write-Warning "Gowin returned error. Review $log"
    throw "USBH01 BUILD FAIL: Gowin exit $exitCode"
}
if (!(Test-Path $fs)) {
    Get-ChildItem -Path $Work -File -Recurse -Filter '*.fs' -ErrorAction SilentlyContinue |
        Select-Object FullName,Length,LastWriteTime
    throw "USBH01 BUILD NOT CONFIRMED: no expected .fs at $fs"
}
$item = Get-Item $fs
if ($item.LastWriteTimeUtc -lt $before.AddSeconds(-2)) {
    throw "USBH01 BUILD NOT CONFIRMED: bitstream timestamp predates this build"
}
$hash = Get-FileHash -Path $fs -Algorithm SHA256
Write-Host "USBH01 BITSTREAM FOUND"
Write-Host "FILE: $fs"
Write-Host "BYTES: $($item.Length)"
Write-Host "SHA256: $($hash.Hash)"
Write-Host "STATUS: CLI BUILD FILE PASS; TIMING AND BOARD NOT YET VERIFIED"
