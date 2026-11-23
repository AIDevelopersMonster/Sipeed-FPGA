create_clock -name clk -period 37.037 [get_ports {clk}]
create_generated_clock -name fclk -source [get_ports {clk}] -multiply_by 5 [get_pins {pll/CLKOUT}]
create_generated_clock -name pclk -source [get_pins {pll/CLKOUT}] -master_clock fclk -divide_by 5 [get_pins {div5/CLKOUT}]
