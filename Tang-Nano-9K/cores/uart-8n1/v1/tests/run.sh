#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2005 -s tb_uart -o "$tmp/tx.vvp" rtl/uart_tx_8n1.v tests/tb_uart_tx.v
vvp "$tmp/tx.vvp" | tee "$tmp/tx.log"
grep -q 'UART TB PASS:' "$tmp/tx.log"
iverilog -g2005 -s tb_uart_rx -o "$tmp/rx.vvp" rtl/uart_rx_8n1.v tests/tb_uart_rx.v
vvp "$tmp/rx.vvp" | tee "$tmp/rx.log"
grep -q 'LAB02_RX_RTL_PASS:' "$tmp/rx.log"
iverilog -g2005 -s tb_uart_loopback -o "$tmp/loop.vvp" rtl/uart_tx_8n1.v rtl/uart_rx_8n1.v tests/tb_uart_loopback.v
vvp "$tmp/loop.vvp" | tee "$tmp/loop.log"
grep -q 'UART_CORE_LOOPBACK_PASS:' "$tmp/loop.log"
echo 'UART_CORE_SIM_PASS: TX, RX and independent loopback'
