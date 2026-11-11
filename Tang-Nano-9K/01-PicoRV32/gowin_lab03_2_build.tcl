# LAB-03.2 variant. Distinct top and output; LAB-02 project is not modified.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/tang_nano_9k.cst
add_file constraints/tang_nano_9k.sdc
add_file rtl/picorv32_soc_lab03.v
add_file rtl/lab03_trace_capture.v
add_file rtl/lab03_boot_rom.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file vendor/picorv32/picorv32.v
set_option -top_module picorv32_soc_lab03
set_option -output_base_name picorv32_lab03_nano9k
set_option -synthesis_tool gowinsynthesis
run all
