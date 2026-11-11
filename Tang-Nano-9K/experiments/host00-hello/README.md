# HOST-00 — UART HELLO only, modular assembly (no SD access)

**Status (2026-10-24): RTL SIM PASS · Gowin PnR PASS · internal STA PASS · HOST00_BOARD_PASS (three observed UART replies).** [Physical acceptance receipt](acceptance/HOST00_UART_SMOKE_2026-10-24.md).

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

Test with `bash experiments/host00-hello/tests/run.sh`. The separate HOST-00.1 Gowin build, internal STA and physical UART command/response have now been operator-tested. LAB-02 TX17/RX18 was the earlier pin-mapping precedent; the actual HOST-00 receipt is linked above. These results do not qualify future modified RTL without repeating the relevant tests.

## HOST-00.1 Tang Nano 9K physical build and acceptance

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

**STOP:** Never program the bitstream until SHA/STA pass. Only then use the existing verified `01-PicoRV32/lab04/tools/program_lab04_sram.ps1` in **SRAM-only** mode. For the actual COM test, close other terminal apps, then run `python -m pip install pyserial` (if needed) and `python .\experiments\host00-hello\tools\host00_hello.py --port COM10` with your real COM number. The board-facing UART acceptance was recorded for three replies at COM10; separate programmer command output has not been archived. A different bitstream still requires its own checks.

## Published video demonstration and interactive HTML labs

[**YouTube — HOST-00.1: FPGA + Python, UART, FIFO, LIFO and three HTML labs**](https://youtu.be/5tMD8-dtKhw) — published by the project author after recording the real board test and demonstrating the three educational browser pages.

Each HTML is standalone, works locally with no CDN, and is an *educational software model*, not a live connection to FPGA:

- [FIFO — circular buffer, pointers, valid/ready and one-cycle operations](../../cores/fifo-sync/v1/demo/index.html)
- [LIFO — stack, top pointer and push/pop](../../cores/lifo-sync/v1/demo/index.html)
- [UART 8N1 — bit frame, TX waveforms, center sampling and stop-bit error](../../cores/uart-8n1/v1/demo/index.html)

Hardware status: PC Python → UART RX → RX FIFO → HELLO handler → TX FIFO → UART TX → PC, three replies in the operator-provided COM10 log. No direct SD-card block interface or write commands are part of HOST-00.1.
