# Complete SD RW PnR resource study ONLY; never use bitstream.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/sd_rw.cst
add_file constraints/sd_rw.sdc
add_file rtl/spi_byte.v
add_file rtl/sd_read_sector.v
add_file rtl/sd06_cmd24_engine.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file rtl/sd06_rw_bridge_top.v
add_file rtl/sd06_rw_measure_top.v
set_option -top_module sd06_rw_measure_top
set_option -output_base_name sd06_rw_measure_NOPERMIT
set_option -synthesis_tool gowinsynthesis
run all
