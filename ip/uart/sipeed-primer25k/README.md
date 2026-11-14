# Sipeed Tang Primer 25K: UART reference RTL

Source: https://github.com/sipeed/TangPrimer-25K-example/tree/main/UART/simple_uart

## Scope

Vendor UART demo source copied as **complete Verilog RTL** (top, TX, RX), with Chinese-language output replaced by ASCII `FPGA UART OK\r\n`. Chinese comments are replaced with English placeholders. `top.cst` pin assignment retained from upstream. This fork is not a byte-identical vendor copy and needs a fresh build/test.

## Parameters and pins

- `CLK_FRE = 50` MHz, `UART_FRE = 115200` bps.
- `clk = E2`, `rst = H11`, `uart_rx = B3`, `uart_tx = C3`.
- Top module: `uart_test` (in `uart_top.v`).
- TX and RX are independent synchronous FSMs, no IP core required. `sample_clk` uses Gowin OSCA for GAO sampling, so top is board-specific.
- Sends greeting every ~1 second and echoes incoming bytes.

## Evidence and claim boundaries

- **BOARD PASS (upstream factory prebuilt image, observed 2026-11-14):** serial terminal displayed `你好  GOWIN` repeatedly on Tang Primer 25K.
- **NOT YET TESTED:** this ASCII-modified RTL build, synthesis, timing, SRAM programming and hardware behavior.
- Do not claim the modified source has been flashed or tested. Prefer SRAM programming for initial verification.

## Files

- `rtl/uart_top.v` - UART Hello state machine and ASCII output.
- `rtl/uart_tx.v` - transmitter.
- `rtl/uart_rx.v` - receiver.
- `top.cst` - vendor board pin mapping.

Licence: see original repository licensing and retain upstream attribution. Check the applicable upstream licence before redistributing as an independent packaged IP release.
