// Tang Nano 20K primary 27MHz and known Sipeed 720p CLKDIV pixel clock.
// CDC STA routes must be inspected on the new design; no blanket false paths.
create_clock -name clk27 -period 37.037 [get_ports {clk27}]
create_clock -name pix_clk -period 13.468 [get_pins {u_clkdiv/CLKOUT}]
