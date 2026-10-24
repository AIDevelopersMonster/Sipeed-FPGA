# SD-04.2, read-only FAT32 root first-sector probe. Build only, never program Flash.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/sd04_nano9k.cst
add_file constraints/sd04_nano9k.sdc
add_file core/spi_byte.v
add_file core/sd_read_sector.v
add_file rtl/uart_tx_8n1.v
add_file rtl/sd03_mbr_parser.v
add_file rtl/sd03_fat32_bpb.v
add_file rtl/sd03_volume_scanner.v
add_file rtl/sd04_directory_parser.v
add_file rtl/sd04_uart_report.v
add_file rtl/sd04_directory_probe_top.v
set_option -top_module sd04_directory_probe_top
set_option -output_base_name sd04_directory_nano9k
set_option -synthesis_tool gowinsynthesis
run all
