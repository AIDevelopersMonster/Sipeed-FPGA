# PiKoSoL 20K PicoRV32, SRAM candidate. This TCL NEVER programs Flash.
set_device -name GW2AR-18C GW2AR-LV18QN88C8/I7
add_file constraints/pikosol20k.cst
add_file constraints/pikosol20k.sdc
add_file rtl/pikosol20k_top.v
add_file rtl/pikosol20k_reset_ctrl.v
add_file rtl/pikosol20k_renderer.v
add_file rtl/pikosol20k_cpu_soc.v
add_file rtl/pikosol20k_video_cmd_cdc.v
add_file rtl/lab04_boot_rom.v
add_file rtl/lab04_tty_byte_cdc.v
add_file rtl/lab04_led_mask_cdc.v
add_file rtl/lab04_uart_tty_bridge.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file vendor/picorv32.v
add_file vendor/TMDS_rPLL.v
add_file vendor/dvi_tx.v
set_option -top_module pikosol20k_top
set_option -output_base_name pikosol20k_picorv32_candidate
set_option -synthesis_tool gowinsynthesis
run all
