# SD-04 hardware-only root-sector dump, frozen SD-03 source deps.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file ../sd-mbr-fat32/constraints/sd03_nano9k.cst
add_file ../sd-mbr-fat32/constraints/sd03_nano9k.sdc
add_file ../sd-mbr-fat32/rtl/spi_byte.v
add_file ../sd-mbr-fat32/rtl/sd_read_sector.v
add_file ../sd-mbr-fat32/rtl/uart_tx_8n1.v
add_file ../sd-mbr-fat32/rtl/sd03_mbr_parser.v
add_file ../sd-mbr-fat32/rtl/sd03_fat32_bpb.v
add_file ../sd-mbr-fat32/rtl/sd03_volume_scanner.v
add_file rtl/sd04_root_dump_top.v
set_option -top_module sd04_root_dump_top
set_option -output_base_name sd04_root_dump_nano9k
set_option -synthesis_tool gowinsynthesis
run all
