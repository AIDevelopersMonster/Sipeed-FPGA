// LAB-07: 27MHz input. PLL generates 81MHz main and 90-degree phase.
create_clock -name sys_clk -period 37.037 -waveform {0 18.518} [get_ports {sys_clk}]
// CHECK Gowin derived 81MHz clock and phase shift after place/route.
// This SDC alone is NOT complete signoff for the DDR PSRAM interface.
