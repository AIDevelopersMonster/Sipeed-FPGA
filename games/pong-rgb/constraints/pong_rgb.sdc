// Minimal timing clock; Gowin STA report must be independently checked.
create_clock -name clk_27mhz -period 37.037 -waveform {0 18.518} [get_ports {clk}]
