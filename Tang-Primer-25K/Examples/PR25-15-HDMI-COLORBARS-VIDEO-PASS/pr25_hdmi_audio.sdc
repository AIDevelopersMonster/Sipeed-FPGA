// Timing constraints: baseline of thisiseth Tang Primer 25K SPI-IO project.
// PLL has 75MHz pixel and 375MHz x5 clocks; audio is approx 48.015kHz.
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_generated_clock -name clk_hdmi_pixel -source [get_ports {clk_50m}] -master_clock clk_50m -multiply_by 3 -divide_by 2 [get_pins {pll_hdmi/PLLA_inst/CLKOUT0}]
create_generated_clock -name clk_hdmi_pixel_x5 -source [get_ports {clk_50m}] -master_clock clk_50m -multiply_by 15 -divide_by 2 [get_pins {pll_hdmi/PLLA_inst/CLKOUT1}]
create_generated_clock -name clk_audio_48k -source [get_ports {clk_50m}] -master_clock clk_50m -multiply_by 3 -divide_by 3124 [get_nets {clk_audio}]
