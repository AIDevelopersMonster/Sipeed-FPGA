# PR25-08. A2600Nano-v2.5-derived clock periods, only this test's clocks.
create_clock -name clk_50mhz -period 20 -waveform {0 10} [get_ports {clk_50mhz}]
create_clock -name clk_pixel_x5 -period 6.984 -waveform {0 3.492} [get_nets {clk_pixel_x5}] -add
create_clock -name clk -period 34.921 -waveform {0 17.460} [get_nets {clk}] -add
report_timing -hold -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
report_timing -setup -from_clock [get_clocks {clk*}] -to_clock [get_clocks {clk*}] -max_paths 25 -max_common_paths 1
