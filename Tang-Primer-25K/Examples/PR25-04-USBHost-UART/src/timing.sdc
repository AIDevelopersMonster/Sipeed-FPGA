// Adapted from upstream USB PLL SDC; no video constraints.
create_clock -name clk_50m -period 20 -waveform {0 10} [get_ports {clk_50m}]
create_generated_clock -name clk_usb_48m -source [get_ports {clk_50m}] -master_clock clk_50m -multiply_by 23 -divide_by 24 [get_pins {pll_usb/PLLA_inst/CLKOUT0}]
create_generated_clock -name clk_usb_48m_x2 -source [get_ports {clk_50m}] -master_clock clk_50m -multiply_by 23 -divide_by 12 -phase 45 [get_pins {pll_usb/PLLA_inst/CLKOUT1}]
