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

## HOST-00.1 Tang Nano 9K physical build candidate

- `constraints/host00_nano9k.cst`: verified historical LAB-02 pins, CLK=52, RESET=3, RX=18, TX=17.
- `build.tcl` + `build.ps1`: isolated Gowin build directory using source snapshots from shared `cores/uart-8n1/v1` and `cores/fifo-sync/v1`, including a per-file SHA-256 manifest. **Build only; does not program FPGA.**
- `check_sta.ps1`: separately checks a generated bitstream hash, setup/hold endpoint count and TNS, prints resources and timing paths and verifies pin mapping; refuses an invalid or incomplete report.
- `tools/host00_hello.py`: simple Python 3 CLI using `pyserial` to send one `H` byte and require the exact `HELLO\\n` reply. Independent unit tests mock the serial transport and check successes and failures. This script **does not communicate with SD**.

### Windows verification

```powershell
cd C:\GitHub\Sipeed-FPGA-LAB05
git switch agent/host00-modular-uart-fifo-lifo
git pull --ff-only
& .\cores\uart-8n1\v1\test.ps1
& .\experiments\host00-hello\test.ps1
& .\experiments\host00-hello\build.ps1
```

After the build, copy the full run path and SHA-256 from its output and execute:

```powershell
& .\experiments\host00-hello\check_sta.ps1 -RunDir 'C:\...\build\run_...' -ExpectedSHA256 '<64-character hash>'
```

**STOP:** Never program the bitstream until SHA/STA pass. Only then use the existing verified `01-PicoRV32/lab04/tools/program_lab04_sram.ps1` in **SRAM-only** mode. For the actual COM test, close other terminal apps, then run `python -m pip install pyserial` (if needed) and `python .\experiments\host00-hello\tools\host00_hello.py --port COM10` with your real COM number. Physical `HOST00_BOARD_PASS` requires observed UART text on the real board and programmer evidence.
