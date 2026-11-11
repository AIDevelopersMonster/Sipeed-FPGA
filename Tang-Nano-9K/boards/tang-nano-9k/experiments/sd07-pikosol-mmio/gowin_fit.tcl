# Experimental PiKoSoL v0.2.0 + SD read/write/MMIO. MEASUREMENT ONLY.
# WRITE LBA 0xFFFFFFFE is synthetic to preserve writer, no physical authorization.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file lab04/constraints/sd07_cpu_hdmi_sd.cst
add_file lab04/constraints/lab04_cpu_video_v018b.sdc
add_file lab04/rtl/lab04_video_clocks.v
add_file lab04/rtl/lab04_led_osd.v
add_file lab04/rtl/lab04_ui_background.v
add_file lab04/rtl/lab04_tty_byte_cdc.v
add_file lab04/rtl/lab04_console_osd.v
add_file lab04/rtl/lab04_graphics_osd.v
add_file lab04/rtl/lab04_video_cmd_cdc.v
add_file lab04/rtl/lab04_uart_tty_bridge.v
add_file lab04/rtl/lab04_led_mask_cdc.v
add_file lab04/rtl/lab04_cpu_soc.v
add_file lab04/rtl/lab04_cpu_hdmi_top.v
add_file lab04/rtl/lab04_boot_rom.v
add_file sd/rtl/sd07_sd_mmio.v
add_file sd/rtl/spi_byte.v
add_file sd/rtl/sd_read_sector.v
add_file sd/rtl/sd06_cmd24_engine.v
add_file rtl/uart_tx_8n1.v
add_file rtl/uart_rx_8n1.v
add_file vendor/picorv32/picorv32.v
add_file vendor/picotiny_ref/gowin_ip/gowin_clkdiv/gowin_clkdiv.v
add_file vendor/picotiny_ref/gowin_ip/gowin_rpll/gowin_rpll.v
add_file vendor/picotiny_ref/hw/hdmi/svo_defines.vh
add_file vendor/picotiny_ref/hw/hdmi/svo_enc.v
add_file lab04/rtl/lab04_svo_hdmi_top.v
add_file vendor/picotiny_ref/hw/hdmi/svo_openldi.v
add_file vendor/picotiny_ref/hw/hdmi/svo_tcard.v
add_file vendor/picotiny_ref/hw/hdmi/svo_term.v
add_file vendor/picotiny_ref/hw/hdmi/svo_tmds.v
add_file vendor/picotiny_ref/hw/hdmi/svo_utils.v
add_file vendor/picotiny_ref/hw/hdmi/svo_vdma.v
set_option -top_module lab04_cpu_hdmi_top
set_option -output_base_name sd07_pikosol_fit_only
set_option -synthesis_tool gowinsynthesis
run all
