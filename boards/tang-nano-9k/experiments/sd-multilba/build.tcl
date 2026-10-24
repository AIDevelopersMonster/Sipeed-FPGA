# SD-02 multi-LBA read-only standalone Tang Nano 9K probe
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/sd02_nano9k.cst
add_file constraints/sd02_nano9k.sdc
add_file rtl/spi_byte.v
add_file rtl/sd_read_sector.v
add_file rtl/uart_tx_8n1.v
add_file rtl/sd02_multilba_probe_top.v
set_option -top_module sd02_multilba_probe_top
set_option -output_base_name sd02_multilba_nano9k
set_option -synthesis_tool gowinsynthesis
run all
