set_device -name GW2A-18C GW2A-LV18PG256C8/I7
add_file src/hdmi/hdmi_defs.vh
add_file src/hdmi/hdmi_tmds_encoder.v
add_file src/hdmi/hdmi_packet_ecc.v
add_file src/hdmi/hdmi_packets.v
add_file src/hdmi/hdmi_island_scheduler.v
add_file src/hdmi/hdmi_data_island.v
add_file src/hdmi/hdmi_tx.v
add_file src/tone_1k.v
add_file src/overlay.v
add_file src/top.v
add_file src/top.cst
add_file src/top.sdc
set_option -top_module top
set_option -output_base_name top
set_option -include_path {.}
set_option -use_sspi_as_gpio 1
set_option -use_done_as_gpio 1
run all
