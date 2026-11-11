# LAB-05.1 stand-alone SD read-only probe, no PicoRV32 or HDMI.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file lab05/constraints/lab05_sd_probe.cst
add_file lab05/constraints/lab05_sd_probe.sdc
add_file lab05/rtl/lab05_spi_byte.v
add_file lab05/rtl/lab05_sd_init_read0.v
add_file lab05/rtl/lab05_sd_probe_top.v
add_file rtl/uart_tx_8n1.v
set_option -top_module lab05_sd_probe_top
set_option -output_base_name lab05_sd_probe_nano9k
set_option -synthesis_tool gowinsynthesis
run all
