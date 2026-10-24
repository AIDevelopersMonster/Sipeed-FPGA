# HOST-00 — UART HELLO only, modular assembly (no SD access)

**Status: initial isolated RTL + regression, hardware build/STA and physical loopback not yet accepted.**

This experiment composes already separate UART TX/RX and FIFO cores using a compact top. The command interpreter is its own tiny module. **No USB MSC, no SD read/write, no FAT32 and no new SPI controller**.

```text
COM / USB-UART
  -> uart_rx_8n1.v
  -> sync_fifo.v (RX, 8 entries)
  -> host00_hello.v (H -> HELLO\n)
  -> sync_fifo.v (TX, 8 entries)
  -> uart_tx_8n1.v
  -> COM / USB-UART
```

Expected operation: send byte `H` (0x48) at **115200 8N1**, receive `HELLO\n`. Other bytes have no response. This is a deliberately tiny educational proof of the modular architecture, **not a robust host protocol**.

Sources are referenced from canonical independent folders:
- `cores/uart-8n1/v1/rtl/`
- `cores/fifo-sync/v1/rtl/`
- `experiments/host00-hello/rtl/` (command handler and wiring only)

LIFO is located in `cores/lifo-sync/v1/` with independent tests; it is not appropriate for UART byte order.

Limitations: RX FIFO overflow or UART framing error is not yet reported to the host (can be checked in simulation); no command framing, packet CRC or timeouts. Sending many H requests without waiting is not guaranteed. For later binary reads implement framing, explicit flow control and error reporting in separate modules.

Test with `bash experiments/host00-hello/tests/run.sh`. A new Gowin build with explicit IO assignments, timing STA and physical UART receipt is required before calling this hardware tested. Verified LAB-02 TX17/RX18 are only historical precedent.
