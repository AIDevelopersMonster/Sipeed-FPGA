# PR25-06 UART-IDLE: source-isolation test

This test drives FPGA pin **C3** (UART TX -> onboard BL616) permanently HIGH (UART idle). It has **no clock, reset, state, PLL, CDC, processor, memory or transmit framing**. It does not use USB or other I/O.

Purpose: distinguish bytes emitted by our FPGA UART transmitter from bytes generated or retained by the BL616/USB/Windows bridge. A correct 9600 or 115200 read **after** programming, settling and clearing the receiver buffer should return zero newly received bytes, assuming BL616 input is not floating and hardware works as intended.

PowerShell:
```powershell
$base='https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-06-UART-IDLE'
Invoke-WebRequest "$base/Build_UART_IDLE.ps1" -OutFile C:\GitHub\Build_UART_IDLE.ps1
& C:\GitHub\Build_UART_IDLE.ps1
# IMPORTANT: using the existing SRAM-only programmer from PR25-05, NOT Flash:
& C:\GitHub\Program_SRAM_UARTTX.ps1 -File C:\GitHub\TangPrimer25K_UART_IDLE\impl\pnr\pr25_uart_idle.fs
# Download and run the timestamped probe from PR25-05:
$probe='https://raw.githubusercontent.com/AIDevelopersMonster/Sipeed-FPGA/main/Tang-Primer-25K/Examples/PR25-05-UART-TX/Capture_UART_Stable.ps1'
Invoke-WebRequest $probe -OutFile C:\GitHub\Capture_UART_Stable.ps1
& C:\GitHub\Capture_UART_Stable.ps1 -Port COM25 -Baud 9600 -Seconds 10
```

Do not use Flash programming. Close all other serial-terminal apps first. Unexpected bytes after clearing buffer would implicate the UART bridge path or electrical level, not this RTL. No bytes does not prove that the USB Host, CPU, PLL, or prior UART state was correct.

Status: source created for operator validation; not yet synthesized/programmed/tested on board.
