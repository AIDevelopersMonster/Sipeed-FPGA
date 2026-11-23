# Tang Nano 9K LAB-00. Run from an isolated directory created by build.ps1.
# No programming, no Flash writes, no vendor IP or CPU.
set_device -name GW1NR-9C GW1NR-LV9QN88PC6/I5
add_file constraints/lab00_led.cst
add_file constraints/lab00_led.sdc
add_file rtl/lab00_led_top.v
set_option -top_module lab00_led_top
set_option -output_base_name tang_nano9k_lab00_led
set_option -synthesis_tool gowinsynthesis
run all
