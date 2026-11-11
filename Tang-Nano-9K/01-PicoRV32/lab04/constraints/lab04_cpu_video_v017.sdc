// LAB-04 board input clock: 27.000 MHz. Gowin rPLL and CLKDIV derive video clocks.
// Check the generated timing report for PLL-derived clocks and all violations.
create_clock -name clk27 -period 37.037 [get_ports {clk}]

// LAB-04 v0.1.3 CDC constraints. First-stage sampling is an intentional
// clock-domain crossing (CDC), not a synchronous data transfer at 2.646 ns.
// Keep the paths ROUTED and BOUNDED: no false_path, no clock_groups.
// 12 ns < 27 MHz source clock period (37.037 ns); protects Gray pointer
// coherence from widely different routing latency among individual bits.
// Paths below are based on the v0.1.1 STA physical endpoint report; verify ACTUAL matches
// in Gowin timing constraints report after every Gowin rebuild.
// Reset release is internally resynchronized in SVO terminal oclk.
set_max_delay -from [get_regs {u_clock/sys_release_q_2_s1}] -to [get_regs {u_hdmi/u_term/oresetn_q_0_s0}] 12.000
// Gray-coded start pointer: sys_clk => first pixel synchronizer stage.
// Gowin grouped B1 registers into packed cells with DI[bit] pins.
// get_regs {mem_start_B1_*} returned TA1124 (no matches) in Gowin 1.9.9 Beta-4.
// get_pins targets the 11 physical DI endpoints observed in v0.1.1 STA.
set_max_delay -from [get_regs {u_hdmi/u_term/mem_start_GR_*}] -to [get_pins {u_hdmi/u_term/mem_start_B1_0_s*/DI*}] 12.000
// Gray-coded stop pointer: sys_clk => first pixel synchronizer stage.
// get_pins targets the corresponding 11 physical DI endpoints.
set_max_delay -from [get_regs {u_hdmi/u_term/mem_stop_GR_*}] -to [get_pins {u_hdmi/u_term/mem_stop_B1_0_s*/DI*}] 12.000

// LAB-04.2 v0.1.6a: point-to-point bounded CDC paths (27.0 to 25.2 MHz).
// This is the CPU variant only. Original lab04_video.sdc remains untouched
// for the Smoke build. Do not use global set_clock_groups/set_false_path.
// The request and ACK use two flip-flop synchronizers. The six-bit data
// mailbox stays stable until acknowledged, then mask_pixel captures it.
// Limit delay without pretending these CDC paths are synchronous setup.
set_max_delay -from [get_regs {u_led_cdc/req_sys_s2}] -to [get_regs {u_led_cdc/req_meta_pixel_s1}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_0_s0}] -to [get_regs {u_led_cdc/mask_pixel_0_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_1_s0}] -to [get_regs {u_led_cdc/mask_pixel_1_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_2_s0}] -to [get_regs {u_led_cdc/mask_pixel_2_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_3_s0}] -to [get_regs {u_led_cdc/mask_pixel_3_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_4_s0}] -to [get_regs {u_led_cdc/mask_pixel_4_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/mask_hold_sys_5_s0}] -to [get_regs {u_led_cdc/mask_pixel_5_s0}] 12.000
set_max_delay -from [get_regs {u_led_cdc/ack_pixel_s0}] -to [get_regs {u_led_cdc/ack_meta_sys_s1}] 12.000

// LAB-04.3 CANDIDATE CDC bounds for 28-bit command mailbox.
// These wildcard endpoints MUST be checked against actual Gowin PnR output.
// No full STA PASS may be claimed merely because the constraints parse.
// Should any group match zero paths, audit physical endpoint names and revise.
set_max_delay -from [get_regs {u_video_cdc/req_sys*}] -to [get_regs {u_video_cdc/req_meta_pixel*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/ack_pixel*}] -to [get_regs {u_video_cdc/ack_meta_sys*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/packet_hold_sys*}] -to [get_regs {u_video_cdc/event_index*}] 12.000
set_max_delay -from [get_regs {u_video_cdc/packet_hold_sys*}] -to [get_regs {u_video_cdc/event_value*}] 12.000

# Full28 diagnostic reporting only
report_exceptions -setup -max_paths 64 -max_common_paths 1
