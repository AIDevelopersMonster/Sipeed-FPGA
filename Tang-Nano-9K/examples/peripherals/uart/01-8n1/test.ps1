# Independent TX+RX UART simulations; no CPU or board.
$ErrorActionPreference='Stop'
$repo=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..\..\..')).Path
$cpu=Join-Path $repo '01-PicoRV32'
$iverilog=(Get-Command iverilog -ErrorAction Stop).Source
$vvp=(Get-Command vvp -ErrorAction Stop).Source
foreach($entry in @(
    @('tb_uart','rtl\uart_tx_8n1.v','tests\tb_uart.v'),
    @('tb_uart_rx','rtl\uart_rx_8n1.v','tests\tb_uart_rx.v')
)) {
    $exe=Join-Path ([System.IO.Path]::GetTempPath()) ("uart_"+[guid]::NewGuid().ToString('N')+".vvp")
    try {
        & $iverilog -g2012 -s $entry[0] -o $exe (Join-Path $cpu $entry[1]) (Join-Path $cpu $entry[2])
        if($LASTEXITCODE -ne 0) { throw "UART $($entry[0]) compilation failed" }
        & $vvp $exe
        if($LASTEXITCODE -ne 0) { throw "UART $($entry[0]) simulation failed" }
    } finally {
        Remove-Item -LiteralPath $exe -Force -ErrorAction SilentlyContinue
    }
}
