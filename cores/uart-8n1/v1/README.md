# UART 8N1 — independent RTL core, v1

**Self-contained, reusable hardware component.** TX and RX are extracted **byte-for-byte** from the already tested PicoRV32 LAB-02 UART code; the transmitter is also identical to the one used by SD-02/03/04. No existing lab source is modified. This extracted core is not itself a completed, separately reprogrammed board experiment.

| Module | Origin | Blob SHA |
|---|---|---|
| `rtl/uart_tx_8n1.v` | `01-PicoRV32/rtl/uart_tx_8n1.v` | `1bb496746768c6866631060e1cfb694b958300df` |
| `rtl/uart_rx_8n1.v` | `01-PicoRV32/rtl/uart_rx_8n1.v` | `c59c1aab532d6b2fcecd01fed400ab2047d108f6` |

## Interface contracts

TX module `uart_tx_8n1`: inputs `clk, reset_n, start, data[7:0]`; outputs `tx, busy`. Pulse `start` when `busy=0`. Requests received while busy are not queued. TX idle=1, 8 data bits LSB-first, no parity, one stop bit.

RX module `uart_rx_8n1`: inputs `clk, reset_n, rx`; outputs `data[7:0], valid, framing_error`. Two-flop synchronizer, center sampling, one-clock `valid` or `framing_error` pulse. There is no oversampling, autobaud, parity or internal FIFO. Consumers must latch the byte on `valid`.

Default parameters: `CLOCK_HZ=27000000`, `BAUD=115200`. Rounded clock divider is 234, giving about 115385 baud (+0.16%). The baud divider is 16-bit. Both modules are plain Verilog-2005, no dependency on PicoRV32, SDHC or any SoC.

## Structure

```text
cores/uart-8n1/v1/
  rtl/uart_tx_8n1.v
  rtl/uart_rx_8n1.v
  tests/tb_uart_tx.v
  tests/tb_uart_rx.v
  tests/tb_uart_loopback.v
  tests/run.sh
  test.ps1
  README.md
  INTEGRATION.md
```

Existing original TX/RX testbenches are copied byte-for-byte (only test file path for TX changed); new loopback test checks 5 byte values from TX to RX.

### Test commands

Windows PowerShell 7 from repository root:
```powershell
& .\cores\uart-8n1\v1\test.ps1
```

Linux / GitHub Actions:
```bash
bash cores/uart-8n1/v1/tests/run.sh
```

Expected final marker: `UART_CORE_SIM_PASS: TX, RX and independent loopback`.

**Boundaries:** This core is serial-byte transport only. FIFO buffering, packet framing, CRC, HELLO/Python host protocol and SDHC commands belong to other independent modules. We do not add them here. Before introducing it into a new hardware top, independently review Gowin PnR/STA and board IO.

[LAB-02 physical bidirectional UART precedent](../../../docs/LAB02_UART_RX_RU.md).
