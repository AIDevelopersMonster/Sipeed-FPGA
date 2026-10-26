// Minimal reference clock; independently inspect generated-clock constraints,
// unconstrained paths and full post-route timing before physical acceptance.
create_clock -name clk_27mhz -period 37.037 -waveform {0 18.518} [get_ports {clk}]
