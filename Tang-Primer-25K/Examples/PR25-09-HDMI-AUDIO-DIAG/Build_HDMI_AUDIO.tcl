# PR25-09. AUDIO DIAGNOSTIC BUILD ONLY. Do not change FPGA SRAM or configuration Flash.
set_device -name GW5A-25A GW5A-LV25MG121NC1/I0
set_option -synthesis_tool gowinsynthesis
set_option -top_module pr25_hdmi_audio_top
set_option -output_base_name pr25_hdmi_audio_diag
set_option -verilog_std sysv2017
set_option -vhdl_std vhd2008
set_option -use_cpu_as_gpio 1
set_option -bit_security 0
set_option -bit_compress 1
# Repo layout: Tang-Primer-25K/Examples/PR25-08.. -> root in ../../../
set lib [file normalize [file join [pwd] .. .. .. ip hdmi a2600nano-primer25k vendor]]
if {![file exists [file join $lib src hdmi hdmi.sv]]} {
    error "Missing pinned source IP at $lib. Fetch ip/hdmi/a2600nano-primer25k."
}
add_file rtl/pr25_hdmi_audio_top.vhd
add_file rtl/hdmi_audio_bars.sv
foreach src {
    audio_clock_regeneration_packet.sv
    audio_info_frame.sv
    audio_sample_packet.sv
    auxiliary_video_information_info_frame.sv
    hdmi.sv
    packet_assembler.sv
    packet_picker.sv
    serializer.sv
    source_product_description_info_frame.sv
    tmds_channel.sv
} {
    add_file [file join $lib src hdmi $src]
}
add_file [file join $lib src tang primer25k gowin_pll_ntsc_mod.vhd]
add_file [file join $lib src tang primer25k gowin_pll_ntsc.vhd]
add_file [file join $lib src tang primer25k pll_init.v]
add_file pins.cst
add_file timing.sdc
run all
