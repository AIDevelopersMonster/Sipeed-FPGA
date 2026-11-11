# Run from isolated build workdir created by build.ps1; no change to LAB-04.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file breakout/constraints/breakout_rgb.cst
add_file breakout/constraints/breakout_rgb.sdc
add_file breakout/rtl/breakout_uart_hdmi_top.v
add_file breakout/rtl/breakout_rgb_core.v
add_file lab04/rtl/lab04_video_clocks.v
add_file rtl/uart_rx_8n1.v
add_file vendor/picotiny_ref/gowin_ip/gowin_clkdiv/gowin_clkdiv.v
add_file vendor/picotiny_ref/gowin_ip/gowin_rpll/gowin_rpll.v
add_file vendor/picotiny_ref/hw/hdmi/svo_defines.vh
add_file vendor/picotiny_ref/hw/hdmi/svo_enc.v
add_file vendor/picotiny_ref/hw/hdmi/svo_tcard.v
add_file vendor/picotiny_ref/hw/hdmi/svo_tmds.v
add_file vendor/picotiny_ref/hw/hdmi/svo_utils.v
add_file vendor/picotiny_ref/hw/hdmi/svo_vdma.v
set_option -top_module breakout_uart_hdmi_top
set_option -output_base_name pikosol_breakout_rgb_nano9k
set_option -synthesis_tool gowinsynthesis
run all
