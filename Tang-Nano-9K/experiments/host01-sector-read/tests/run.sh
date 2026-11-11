#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/../../.." && pwd)"
lab="$repo_root/experiments/host01-sector-read"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
iverilog -g2005 -s tb_crc16_ccitt -o "$tmp/crc.vvp" \
 "$repo_root/cores/crc16-ccitt/v1/rtl/crc16_ccitt_byte.v" \
 "$repo_root/cores/crc16-ccitt/v1/tests/tb_crc16_ccitt.v"
vvp "$tmp/crc.vvp" | tee "$tmp/crc.log"
grep -q HOST01_CRC16_PASS "$tmp/crc.log"
iverilog -g2005 -s host01_sector_top -o "$tmp/top.vvp" \
 "$repo_root/cores/uart-8n1/v1/rtl/uart_rx_8n1.v" \
 "$repo_root/cores/uart-8n1/v1/rtl/uart_tx_8n1.v" \
 "$repo_root/cores/fifo-sync/v1/rtl/sync_fifo.v" \
 "$repo_root/cores/crc16-ccitt/v1/rtl/crc16_ccitt_byte.v" \
 "$repo_root/boards/tang-nano-9k/cores/sdhc-spi-readonly/v1/rtl/spi_byte.v" \
 "$repo_root/boards/tang-nano-9k/cores/sdhc-spi-readonly/v1/rtl/sd_read_sector.v" \
 "$lab/rtl/host01_sector_engine.v" "$lab/rtl/host01_sector_top.v"
echo HOST01_TOP_ELAB_PASS
python3 -m unittest discover -s "$lab/tests" -p 'test_*.py' -v
