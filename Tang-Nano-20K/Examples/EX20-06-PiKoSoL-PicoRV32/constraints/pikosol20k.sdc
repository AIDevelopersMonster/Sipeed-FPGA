// PiKoSoL 20K timing targets: 27 MHz CPU and 74.25 MHz native 720p.
create_clock -name clk27 -period 37.037 [get_ports {clk27}]
create_clock -name pix_clk -period 13.468 [get_pins {u_clkdiv/CLKOUT}]

// Two-flop CDC toggle mailbox protocol. Only the FIRST register's D input
// is asynchronous; disable *only* these six phase-related crossings.
// Hold and bundled-data correctness require protocol verification independently.
// If any exception is not "Actived" in Gowin report, STOP (do not program).
// Do not disable paths clock-to-clock or between synchronous video registers.
set_false_path -through [get_pins {u_scene/u_byte_cdc/ack_meta_sys*/D}]
set_false_path -through [get_pins {u_scene/u_byte_cdc/req_meta_pixel*/D}]
set_false_path -through [get_pins {u_led_cdc/ack_meta_sys*/D}]
set_false_path -through [get_pins {u_led_cdc/req_meta_pixel*/D}]
set_false_path -through [get_pins {u_graphics_cdc/ack_meta_sys*/D}]
set_false_path -through [get_pins {u_graphics_cdc/req_meta_pixel*/D}]
