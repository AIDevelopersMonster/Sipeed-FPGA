# USBH01: prepare a standalone USB 1.1 HOST + UART project (no FPGA writes)
param([string]$Destination = "C:\GitHub\TangPrimer25K_USBHost_UART")
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$ours = "https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-04-USBHost-UART"
$commit = "cce99075f06d0946c8a70c221118df2c4b57fe2a"
$theirs = "https://raw.githubusercontent.com/thisiseth/tang-primer-25k-spi-io/$commit/src/fpga/spi_io_bridge/src"
New-Item -ItemType Directory -Force $Destination | Out-Null
function Fetch-Source([string]$url,[string]$path) {
    New-Item -ItemType Directory -Force (Split-Path -Parent $path) | Out-Null
    Invoke-WebRequest -Uri $url -OutFile $path
    if (-not (Test-Path $path) -or (Get-Item $path).Length -eq 0) {
        throw "Downloaded file missing or empty: $path"
    }
}
$localFiles = @("usb_keyboard_uart.gprj","src/top.sv","src/pins.cst","src/timing.sdc")
foreach ($f in $localFiles) {
    Fetch-Source "$ours/$f" (Join-Path $Destination ($f.Replace("/", "\")))
}
$vendorFiles = @(
    "gowin/pll_usb.v",
    "usb_host/rv32i.v",
    "usb_host/usb11_phy.v",
    "usb_host/usb11_regs.v",
    "usb_host/usb11_sie.v",
    "usb_host/usb_host.v",
    "usb_host/ucmem/mem.hex"
)
foreach ($f in $vendorFiles) {
    Fetch-Source "$theirs/$f" (Join-Path (Join-Path $Destination "src") ($f.Replace("/", "\")))
}
# RV32I source memory init is relative to project working directory.
New-Item -ItemType Directory -Force (Join-Path $Destination "ucmem") | Out-Null
Copy-Item (Join-Path $Destination "src\usb_host\ucmem\mem.hex") (Join-Path $Destination "ucmem\mem.hex") -Force
# Change vendor default 1 Mbaud to 115200 for debugger COM.
$hostFile = Join-Path $Destination "src\usb_host\usb_host.v"
$txt = [System.IO.File]::ReadAllText($hostFile)
$old = '(?m)^\s*' + [regex]::Escape('`define BAUDCNT 48') + '\s*//\s*1Mb/s'
if (-not [regex]::IsMatch($txt, $old)) {
    throw "Upstream UART divider not found. Refuse a blind patch."
}
$txt = [regex]::Replace($txt, $old, '`define BAUDCNT 416 // 48MHz/416 ~= 115385 baud')
[System.IO.File]::WriteAllText($hostFile, $txt, [System.Text.UTF8Encoding]::new($false))
Write-Host "USBH01 PREPARE: PASS"
Write-Host "UPSTREAM REV: $commit"
Write-Host "PROJECT: $(Join-Path $Destination 'usb_keyboard_uart.gprj')"
Write-Host "UART: 115200 8N1"
Write-Host "BUILD: NOT RUN; BOARD: NOT TESTED"
