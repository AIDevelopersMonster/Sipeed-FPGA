# Sipeed-FPGA / 01-PicoRV32 - Gowin CLI for Tang Nano 9K.
# Compatible with older gw_sh (for example Gowin 1.9.9 Beta-4),
# where open_project is not implemented.
# Execute from 01-PicoRV32; firmware ROM must be generated first.

set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5

add_file constraints/tang_nano_9k.cst
add_file constraints/tang_nano_9k.sdc
add_file rtl/picorv32_soc.v
add_file rtl/boot_rom.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file vendor/picorv32/picorv32.v

set_option -top_module picorv32_soc
set_option -output_base_name picorv32_nano9k
set_option -synthesis_tool gowinsynthesis

run all