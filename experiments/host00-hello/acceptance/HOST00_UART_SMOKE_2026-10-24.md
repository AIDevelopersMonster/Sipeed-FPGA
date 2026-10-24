# HOST-00.1 — physical UART smoke test (preliminary acceptance)

**Date:** 2026-10-24. **Status:** hardware `HELLO` response confirmed once; final repeated-run acceptance pending.

## Test equipment and design

- Tang Nano 9K, 27 MHz clock, UART TX FPGA pin 17 / RX FPGA pin 18, onboard USB-UART.
- Windows PowerShell and Python CLI `experiments/host00-hello/tools/host00_hello.py`.
- Host COM port: `COM10`, 115200 8N1 (default of CLI).
- Independent modules: `uart_rx_8n1`, `sync_fifo` (RX), `host00_hello`, `sync_fifo` (TX), `uart_tx_8n1`, connected by `host00_uart_hello_top`.
- Previously operator-reported full build and STA gate: 0 Setup violations, 0 Hold violations, Setup/Hold TNS 0 ns; logic 189/8640, LUT 165, FF 97. Source of these numbers: user's local `check_sta.ps1` output, not independently rerun by GitHub CI.
- Build run: `run_20261024_153340_888_b948b7`.
- Operator-reported bitstream SHA-256: `E42D3A60D0BA54DDA23DC3563FD6CDF53389E435F88DE29658A638CB30A1A535`. The `HOST00_SHA256_PASS` was reported by the local STA gate.

## Verbatim host-side result supplied by operator

```text
PS C:\GitHub\Sipeed-FPGA-LAB05> python .\experiments\host00-hello\tools\host00_hello.py --port COM10
HOST00_HELLO_PASS: attempt=1 port=COM10 received=b'HELLO\n'
PS C:\GitHub\Sipeed-FPGA-LAB05>
```

## Interpretation and limits

This is a confirmed **single physical serial request/response** for the independent UART/FIFO/command composition. It is not just an Icarus simulation. It does not prove any SD-card sector read, FAT32 operation, CMD24 write, USB Mass Storage, extended traffic tolerance, or board-level timing at other clock speeds.

The transcript does not include the programmer command output, although the successful board response is evidence that a compatible UART responder was running. Do not invent a separate programmer acceptance receipt.

**Final HOST00_BOARD_PASS remains pending** the separately requested repeated test:

```powershell
python .\experiments\host00-hello\tools\host00_hello.py --port COM10 --repeat 3
```

Record those actual lines verbatim and check for three successful responses before upgrading the status. Do not claim three repeats from this one-response capture. Neither this receipt nor a software-side PASS guarantees the serial hardware timing under all error conditions.
