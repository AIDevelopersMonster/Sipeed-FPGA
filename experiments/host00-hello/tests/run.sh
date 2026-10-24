#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
iverilog -g2005 -s tb_host00_hello -o "$tmp/host.vvp" \
 ../../cores/uart-8n1/v1/rtl/uart_tx_8n1.v \
 ../../cores/uart-8n1/v1/rtl/uart_rx_8n1.v \
 ../../cores/fifo-sync/v1/rtl/sync_fifo.v \
 rtl/host00_hello.v rtl/host00_uart_hello_top.v tests/tb_host00_hello.v
vvp "$tmp/host.vvp" | tee "$tmp/host.log"
grep -q HOST00_HELLO_TB_PASS "$tmp/host.log"
