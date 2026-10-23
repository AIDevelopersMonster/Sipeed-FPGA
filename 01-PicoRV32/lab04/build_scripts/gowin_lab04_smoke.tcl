# LAB-04.1 clean standalone Gowin build; execute from a generated staging directory.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file lab04/constraints/lab04_hdmi_smoke.cst
add_file lab04/constraints/lab04_video.sdc
add_file lab04/rtl/lab04_video_clocks.v
add_file lab04/rtl/lab04_led_osd.v
add_file lab04/rtl/lab04_hdmi_smoke_top.v
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
set_option -top_module lab04_hdmi_smoke_top
set_option -output_base_name lab04_hdmi_smoke_nano9k
set_option -synthesis_tool gowinsynthesis
run all
