# SD-03.4 autonomous MBR/FAT32 discovery; Tang Nano 9K SRAM candidate.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/sd03_nano9k.cst
add_file constraints/sd03_nano9k.sdc
add_file rtl/spi_byte.v
add_file rtl/sd_read_sector.v
add_file rtl/uart_tx_8n1.v
add_file rtl/sd03_mbr_parser.v
add_file rtl/sd03_fat32_bpb.v
add_file rtl/sd03_volume_scanner.v
add_file rtl/sd03_mbr_fat32_probe_top.v
set_option -top_module sd03_mbr_fat32_probe_top
set_option -output_base_name sd03_mbr_fat32_nano9k
set_option -synthesis_tool gowinsynthesis
run all
