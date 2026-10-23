// PiKoSoL LAB-04.3.1B CPU-specific STA for addressable console.
// 27 MHz source, 25.2 MHz pixel, 126 MHz TMDS serializer.
// Old svo_term is NOT instantiated in CPU console mode (only in Smoke mode).
// Its 3 legacy exception endpoints must NOT be required in this CPU variant.
// Explicitly bound LED, graphics and new UART byte CDCs; no global false paths.
create_clock -name clk27 -period 37.037 [get_ports {clk}]

// LED CDC: six data bits plus synchronized request/ack.
set_max_delay -from [get_regs {u_led_cdc/req_sys_s2}] -to [get_regs {u_led_cdc/req_meta_pixel_s1}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_0_s0}] -to [get_regs {u_led_cdc/mask_pixel_0_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_1_s0}] -to [get_regs {u_led_cdc/mask_pixel_1_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_2_s0}] -to [get_regs {u_led_cdc/mask_pixel_2_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_3_s0}] -to [get_regs {u_led_cdc/mask_pixel_3_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_4_s0}] -to [get_regs {u_led_cdc/mask_pixel_4_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_5_s0}] -to [get_regs {u_led_cdc/mask_pixel_5_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/ack_pixel_s0}] -to [get_regs {u_led_cdc/ack_meta_sys_s1}] 12.000

// 28-bit graphics CDC: request, acknowledgment, index+value.
set_max_delay -from [get_regs {u_video_cdc/req_sys*}] -to [get_regs {u_video_cdc/req_meta_pixel*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/ack_pixel*}] -to [get_regs {u_video_cdc/ack_meta_sys*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/packet_hold_sys*}] -to [get_regs {u_video_cdc/event_index*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/packet_hold_sys*}] -to [get_regs {u_video_cdc/event_value*}] 12.000

// New 8-bit UART byte CDC: request, acknowledgment, bundled data.
set_max_delay -from [get_regs {*u_tty_cdc/req_sys*}] -to [get_regs {*u_tty_cdc/req_meta_pixel*}] 12.000
set_max_delay -from [get_regs {*u_tty_cdc/ack_pixel*}] -to [get_regs {*u_tty_cdc/ack_meta_sys*}] 12.000
set_max_delay -from [get_regs {*u_tty_cdc/char_hold_sys*}] -to [get_regs {*u_tty_cdc/event_byte*}] 12.000

// Emit sufficiently many physical routes for a complete bit-by-bit audit.
report_exceptions -setup -max_paths 96 -max_common_paths 1
