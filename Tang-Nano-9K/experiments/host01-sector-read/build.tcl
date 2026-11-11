set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/host01_nano9k.cst
add_file constraints/host01_nano9k.sdc
add_file core/uart_tx_8n1.v
add_file core/uart_rx_8n1.v
add_file core/sync_fifo.v
add_file core/crc16_ccitt_byte.v
add_file core/spi_byte.v
add_file core/sd_read_sector.v
add_file rtl/host01_sector_engine.v
add_file rtl/host01_sector_top.v
set_option -top_module host01_sector_top
set_option -output_base_name host01_sector_nano9k
set_option -synthesis_tool gowinsynthesis
run all
