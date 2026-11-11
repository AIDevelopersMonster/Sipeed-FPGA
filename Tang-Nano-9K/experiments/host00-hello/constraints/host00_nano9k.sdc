// Clock internal STA, 27 MHz Tang Nano 9K crystal.
// The UART RX input is asynchronous to clk27 and is synchronized inside
// the proven receiver; its external timing is not phase-constrained here.
create_clock -name clk27 -period 37.037 [get_ports {clk}]
