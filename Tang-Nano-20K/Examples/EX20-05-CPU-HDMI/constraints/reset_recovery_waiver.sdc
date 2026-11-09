# EX20-05.8: recovery waiver for LiteX system reset synchronizer.
# Only PRESET pins of two DFFP instances.
# Do not waive hold or removal analysis.
set_false_path -setup -from [get_clocks {clk27}] -to [get_pins {DFFP/PRESET}]
set_false_path -setup -from [get_clocks {clk27}] -to [get_pins {DFFP_1/PRESET}]
