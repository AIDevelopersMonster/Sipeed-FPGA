// SD-03 reused interface from LAB-05.1: one 27 MHz internal system clock. SD SCK is a GPIO output,
// not a second internal fabric clock; initial SPI speed ~211 kHz.
create_clock -name clk27 -period 37.037 [get_ports {clk}]
// The SD MISO external return delay is not yet separately characterized.
// Do not claim this file constitutes a complete SD IO timing certification.
