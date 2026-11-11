# HOST-00.1: standalone UART RX + FIFO + HELLO handler + FIFO + UART TX.
# Gowin V1.9.9 Beta-4 compatible; executed from a unique isolated work dir.
# Build only: never program configuration Flash or FPGA SRAM.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/host00_nano9k.cst
add_file constraints/host00_nano9k.sdc
add_file core/uart_rx_8n1.v
add_file core/uart_tx_8n1.v
add_file core/sync_fifo.v
add_file rtl/host00_hello.v
add_file rtl/host00_uart_hello_top.v
set_option -top_module host00_uart_hello_top
set_option -output_base_name host00_uart_hello_nano9k
set_option -synthesis_tool gowinsynthesis
run all
