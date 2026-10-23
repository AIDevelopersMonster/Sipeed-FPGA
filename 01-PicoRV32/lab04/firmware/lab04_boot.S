# PiKoSoL LAB-04.3.2 / v0.2.0-alpha - interactive line shell.
# PicoRV32 RV32I subset. No IRQ, OS/ABI or file-system claims.
# User RAM 0x4000: 48x32-bit input cells, 48x32-bit recall cells at +0x100.
# All commands ENTER terminated; old single-letter controls still work + Enter.
# TERM (default) and GFX modes are selected by CPU TX control bytes 0x0e / 0x0f.
# Pixel overlay interprets them; host terminal may ignore them.
# SPDX-License-Identifier: MIT
.text
.globl _start
_start:
    lui t0, 0x20000
    sw zero, 0(t0)
    lui s2, 0x20000
    addi s2, s2, 256
    addi s3, s2, 0
    lui s8, 0x4       # RAM base 0x00004000; full-word character cells
    addi s11, s8, 0  # current input pointer
    addi s7, zero, 0 # input character count, max 47
    addi s0, zero, 0 # history length
    addi s9, zero, 0 # CRLF filter
    addi s4, zero, 0 # 0=TERM, 1=GFX
    addi s10,zero, 0 # 1=live keys (only in GFX)
    # Graphics defaults deliberately within canvas x32..448, y112..344.
    addi t4, zero, 100
    sw t4, 0(s2)
    addi t4, zero, 180
    sw t4, 4(s2)
    addi t4, zero, 96
    sw t4, 8(s2)
    addi t4, zero, 80
    sw t4, 12(s2)
    addi t4, zero, 255
    sw t4, 16(s2)
    addi t4, zero, 1
    sw t4, 20(s2)
    addi t4, zero, 280
    sw t4, 32(s2)
    addi t4, zero, 212
    sw t4, 36(s2)
    addi t4, zero, 80
    sw t4, 40(s2)
    addi t4, zero, 64
    sw t4, 44(s2)
    addi t4, zero, 255
    slli t4, t4, 16
    sw t4, 48(s2)
    addi t4, zero, 1
    sw t4, 52(s2)
    sw t4, 60(s2)
    .emit "\u000e\f"
    .emit "PiKoSoL INTERACTIVE SHELL v0.2.0\r\n"
    .emit "PicoRV32 / Tang Nano 9K / HDMI 640x480\r\n"
    .emit "Type HELP then Enter. CTRL-P recalls last line.\r\n"
    jal ra, prompt
poll:
    lw t2, 28(t0)
    andi t2, t2, 1
    beq t2, zero, poll
    lw t3, 24(t0)
    bne s10, zero, live_input
    addi t4, zero, 13
    beq t3, t4, enter_cr
    addi t4, zero, 10
    beq t3, t4, enter_lf
    addi s9, zero, 0
    addi t4, zero, 8
    beq t3, t4, backspace
    addi t4, zero, 127
    beq t3, t4, backspace
    addi t4, zero, 16
    beq t3, t4, recall
    # Reject non-printable and ASCII>=127. Avoid signed branch logic.
    addi t4, t3, -32
    srli t4, t4, 31
    bne t4, zero, poll
    addi t4, t3, -127
    srli t4, t4, 31
    beq t4, zero, poll
    addi t4, s7, -47
    srli t4, t4, 31
    beq t4, zero, input_full
    sw t3, 0(s11)
    addi s11, s11, 4
    addi s7, s7, 1
    addi t1, t3, 0
    jal ra, putc
    jal zero, poll
input_full:
    addi t1, zero, 7    # BEL, never overflow RAM
    jal ra, putc
    jal zero, poll
backspace:
    beq s7, zero, poll
    addi s7, s7, -1
    addi s11, s11, -4
    sw zero, 0(s11)
    .emit "\b \b"
    jal zero, poll
enter_cr:
    addi s9, zero, 1
    jal zero, line_enter
enter_lf:
    bne s9, zero, ignore_lf
    jal zero, line_enter
ignore_lf:
    addi s9, zero, 0
    jal zero, poll
line_enter:
    .emit "\r\n"
    beq s7, zero, shell_done
    sw zero, 0(s11)
    # Convert multi-letter command to uppercase. Single-char legacy commands
    # keep case (A/B select vs a/b one-LED).
    addi t4, zero, 1
    beq s7, t4, normalize_done
    addi a0, s8, 0
normalize_loop:
    beq a0, s11, normalize_done
    lw t3, 0(a0)
    addi t4, t3, -97
    srli t4, t4, 31
    bne t4, zero, normalize_next
    addi t4, t3, -123
    srli t4, t4, 31
    beq t4, zero, normalize_next
    addi t3, t3, -32
    sw t3, 0(a0)
normalize_next:
    addi a0, a0, 4
    jal zero, normalize_loop
normalize_done:
    # Remember exactly one previous command, 47 bytes maximum. No heap.
    addi a0, s8, 0
    addi a1, s8, 256
    addi s0, s7, 0
remember_loop:
    beq a0, s11, remember_done
    lw t3, 0(a0)
    sw t3, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    jal zero, remember_loop
remember_done:
    sw zero, 0(a1)
    addi t4, zero, 1
    beq s7, t4, single_command
    jal zero, command_table
recall:
    beq s0, zero, poll
    bne s7, zero, poll
    addi a0, s8, 256
    addi a1, s8, 0
    addi t4, s0, 0
recall_loop:
    beq t4, zero, recall_done
    lw t3, 0(a0)
    sw t3, 0(a1)
    addi t1, t3, 0
    jal ra, putc
    addi a0, a0, 4
    addi a1, a1, 4
    addi t4, t4, -1
    jal zero, recall_loop
recall_done:
    addi s11, a1, 0
    addi s7, s0, 0
    sw zero, 0(s11)
    jal zero, poll
command_table:
    .match "HELP", cmd_help
    .match "INFO", cmd_info
    .match "MEM", cmd_mem
    .verb "LED", cmd_led
    .match "GFX", cmd_gfx
    .match "KEYS", cmd_keys
    .match "TERM", cmd_term
    .match "CLS", cmd_cls
    .verb "OBJ", cmd_obj
    .verb "MOVE", cmd_move
    .verb "COLOR", cmd_color
    .verb "SIZE", cmd_size
    .match "PANEL", panel
    .match "STATUS", query
    jal zero, invalid

live_input:
    # Fast graphics control: ONLY while KEYS enabled; no UART printf per move.
    # T immediately returns to TERM; avoids interpreting a partial shell verb.
    addi t5, zero, 116
    beq t3, t5, cmd_term
    addi t5, zero, 84
    beq t3, t5, cmd_term
    addi t5, zero, 65
    beq t3, t5, select_a
    addi t5, zero, 66
    beq t3, t5, select_b
    addi t5, zero, 105
    beq t3, t5, move_up
    addi t5, zero, 106
    beq t3, t5, move_left
    addi t5, zero, 107
    beq t3, t5, move_down
    addi t5, zero, 108
    beq t3, t5, move_right
    addi t5, zero, 82
    beq t3, t5, color_red
    addi t5, zero, 71
    beq t3, t5, color_green
    addi t5, zero, 85
    beq t3, t5, color_blue
    addi t5, zero, 87
    beq t3, t5, color_white
    addi t5, zero, 88
    beq t3, t5, toggle_on
    addi t5, zero, 79
    beq t3, t5, toggle_outline
    addi t5, zero, 75
    beq t3, t5, toggle_checker
    addi t5, zero, 43
    beq t3, t5, width_plus
    addi t5, zero, 45
    beq t3, t5, width_minus
    jal zero, poll

single_command:
    lw t3, 0(s8)
    addi t5, zero, 48
    beq t3, t5, count0
    addi t5, zero, 49
    beq t3, t5, count1
    addi t5, zero, 50
    beq t3, t5, count2
    addi t5, zero, 51
    beq t3, t5, count3
    addi t5, zero, 52
    beq t3, t5, count4
    addi t5, zero, 53
    beq t3, t5, count5
    addi t5, zero, 54
    beq t3, t5, count6
    addi t5, zero, 97
    beq t3, t5, one1
    addi t5, zero, 98
    beq t3, t5, one2
    addi t5, zero, 99
    beq t3, t5, one3
    addi t5, zero, 100
    beq t3, t5, one4
    addi t5, zero, 101
    beq t3, t5, one5
    addi t5, zero, 102
    beq t3, t5, one6
    addi t5, zero, 65
    beq t3, t5, select_a
    addi t5, zero, 66
    beq t3, t5, select_b
    addi t5, zero, 105
    beq t3, t5, move_up
    addi t5, zero, 106
    beq t3, t5, move_left
    addi t5, zero, 107
    beq t3, t5, move_down
    addi t5, zero, 108
    beq t3, t5, move_right
    addi t5, zero, 82
    beq t3, t5, color_red
    addi t5, zero, 71
    beq t3, t5, color_green
    addi t5, zero, 85
    beq t3, t5, color_blue
    addi t5, zero, 87
    beq t3, t5, color_white
    addi t5, zero, 88
    beq t3, t5, toggle_on
    addi t5, zero, 79
    beq t3, t5, toggle_outline
    addi t5, zero, 75
    beq t3, t5, toggle_checker
    addi t5, zero, 43
    beq t3, t5, width_plus
    addi t5, zero, 45
    beq t3, t5, width_minus
    addi t5, zero, 112
    beq t3, t5, panel
    addi t5, zero, 63
    beq t3, t5, query
    jal zero, invalid

# Typed shell commands. All return via shell_done, including errors.
cmd_help:
    .emit "HELP INFO MEM LED N|? GFX TERM CLS KEYS\r\n"
    .emit "OBJ A|B MOVE I|J|K|L COLOR R|G|U|W\r\n"
    .emit "SIZE +|- PANEL STATUS; single-key commands + Enter.\r\n"
    .emit "CTRL-P recall previous command. No file system yet.\r\n"
    jal zero, shell_done
cmd_info:
    .emit "PiKoSoL LAB-04.3.2 / PicoRV32 RV32I\r\n"
    .emit "Tang Nano 9K; 640x480 HDMI; UART 115200 8N1\r\n"
    .emit "MODE: "
    beq s4, zero, info_term
    .emit "GRAPHICS\r\n"
    jal zero, shell_done
info_term:
    .emit "TERMINAL\r\n"
    jal zero, shell_done
cmd_mem:
    .emit "ROM 16KiB @00000000; RAM 1KiB @00004000\r\n"
    .emit "LINE 47 characters; history 1 command; 32x76 text VRAM.\r\n"
    jal zero, shell_done
cmd_gfx:
    addi s4, zero, 1
    .emit "\u000fMODE: GRAPHICS. MOVE IJKL, OBJ A|B.\r\n"
    jal zero, shell_done
cmd_term:
    addi s4, zero, 0
    addi s10,zero, 0
    .emit "\u000eMODE: TERMINAL\r\n"
    jal zero, shell_done
cmd_keys:
    beq s4,zero,invalid_arg
    addi s10,zero,1
    .emit "LIVE KEYS: ijkl A/B RGUW +/-; T returns to TERM.\r\n"
    jal zero,shell_done
cmd_cls:
    .emit "\fCLEAR: HDMI console history cleared.\r\n"
    jal zero, shell_done
cmd_led:
    lw t4, 16(s8)
    beq t4, zero, query
    addi t5, zero, 63
    beq t4, t5, query
    lw t5, 20(s8)
    bne t5, zero, invalid_arg
    addi t5, zero, 48
    beq t4, t5, count0
    addi t5, zero, 49
    beq t4, t5, count1
    addi t5, zero, 50
    beq t4, t5, count2
    addi t5, zero, 51
    beq t4, t5, count3
    addi t5, zero, 52
    beq t4, t5, count4
    addi t5, zero, 53
    beq t4, t5, count5
    addi t5, zero, 54
    beq t4, t5, count6
    jal zero, invalid_arg
cmd_obj:
    lw t4, 16(s8)
    lw t5, 20(s8)
    bne t5, zero, invalid_arg
    addi t5, zero, 65
    beq t4, t5, select_a
    addi t5, zero, 66
    beq t4, t5, select_b
    jal zero, invalid_arg
cmd_move:
    lw t4, 20(s8)
    lw t5, 24(s8)
    bne t5, zero, invalid_arg
    addi t5, zero, 73
    beq t4, t5, move_up
    addi t5, zero, 74
    beq t4, t5, move_left
    addi t5, zero, 75
    beq t4, t5, move_down
    addi t5, zero, 76
    beq t4, t5, move_right
    jal zero, invalid_arg
cmd_color:
    lw t4, 24(s8)
    lw t5, 28(s8)
    bne t5, zero, invalid_arg
    addi t5, zero, 82
    beq t4, t5, color_red
    addi t5, zero, 71
    beq t4, t5, color_green
    addi t5, zero, 85
    beq t4, t5, color_blue
    addi t5, zero, 87
    beq t4, t5, color_white
    jal zero, invalid_arg
cmd_size:
    lw t4, 20(s8)
    lw t5, 24(s8)
    bne t5, zero, invalid_arg
    addi t5, zero, 43
    beq t4, t5, width_plus
    addi t5, zero, 45
    beq t4, t5, width_minus
    jal zero, invalid_arg

count0:
    addi t4, zero, 0
    addi t5, zero, 48
    jal zero, apply_count
count1:
    addi t4, zero, 1
    addi t5, zero, 49
    jal zero, apply_count
count2:
    addi t4, zero, 3
    addi t5, zero, 50
    jal zero, apply_count
count3:
    addi t4, zero, 7
    addi t5, zero, 51
    jal zero, apply_count
count4:
    addi t4, zero, 15
    addi t5, zero, 52
    jal zero, apply_count
count5:
    addi t4, zero, 31
    addi t5, zero, 53
    jal zero, apply_count
count6:
    addi t4, zero, 63
    addi t5, zero, 54
    jal zero, apply_count

one1:
    addi t4, zero, 1
    addi t5, zero, 49
    jal zero, apply_one
one2:
    addi t4, zero, 2
    addi t5, zero, 50
    jal zero, apply_one
one3:
    addi t4, zero, 4
    addi t5, zero, 51
    jal zero, apply_one
one4:
    addi t4, zero, 8
    addi t5, zero, 52
    jal zero, apply_one
one5:
    addi t4, zero, 16
    addi t5, zero, 53
    jal zero, apply_one
one6:
    addi t4, zero, 32
    addi t5, zero, 54
    jal zero, apply_one

# Bounded graphics: 32<=x and x+width<=448;
# 112<=y and y+height<=344; dimensions 32<=w<=128.
select_a:
    addi s3, s2, 0
    jal zero, video_done
select_b:
    addi s3, s2, 32
    jal zero, video_done
move_up:
    lw t4, 4(s3)
    addi t5, t4, -8
    addi t6, t5, -112
    srli t6, t6, 31
    bne t6, zero, video_done
    sw t5, 4(s3)
    jal zero, video_done
move_down:
    lw t4, 4(s3)
    lw t5, 12(s3)
    addi t4, t4, 8
    add t6, t4, t5
    addi t6, t6, -345
    srli t6, t6, 31
    beq t6, zero, video_done
    sw t4, 4(s3)
    jal zero, video_done
move_left:
    lw t4, 0(s3)
    addi t5, t4, -8
    addi t6, t5, -32
    srli t6, t6, 31
    bne t6, zero, video_done
    sw t5, 0(s3)
    jal zero, video_done
move_right:
    lw t4, 0(s3)
    lw t5, 8(s3)
    addi t4, t4, 8
    add t6, t4, t5
    addi t6, t6, -449
    srli t6, t6, 31
    beq t6, zero, video_done
    sw t4, 0(s3)
    jal zero, video_done
width_plus:
    lw t4, 8(s3)
    addi t4, t4, 8
    addi t6, t4, -129
    srli t6, t6, 31
    beq t6, zero, video_done
    lw t5, 0(s3)
    add t6, t5, t4
    addi t6, t6, -449
    srli t6, t6, 31
    beq t6, zero, video_done
    sw t4, 8(s3)
    jal zero, video_done
width_minus:
    lw t4, 8(s3)
    addi t4, t4, -8
    addi t6, t4, -32
    srli t6, t6, 31
    bne t6, zero, video_done
    sw t4, 8(s3)
    jal zero, video_done
color_red:
    addi t4, zero, 255
    jal zero, set_color
color_green:
    addi t4, zero, 255
    slli t4, t4, 8
    jal zero, set_color
color_blue:
    addi t4, zero, 255
    slli t4, t4, 16
    jal zero, set_color
color_white:
    addi t4, zero, -1
set_color:
    sw t4, 16(s3)
    jal zero, video_done
toggle_on:
    lw t4, 20(s3)
    xori t4, t4, 1
    sw t4, 20(s3)
    jal zero, video_done
toggle_outline:
    lw t4, 20(s3)
    xori t4, t4, 2
    sw t4, 20(s3)
    jal zero, video_done
toggle_checker:
    lw t4, 20(s3)
    xori t4, t4, 4
    sw t4, 20(s3)
    jal zero, video_done
video_done:
    addi t4, zero, 1
    sw t4, 60(s2)
    bne s10, zero, poll
    .emit "V\r\n"
    jal zero, shell_done

panel:
    .emit "+---------------------+\r\n"
    .emit "| PiKoSoL 640x480     |\r\n"
    .emit "| LED ["
    lw t4, 0(t0)
    addi t5, zero, 6
panel_bits:
    andi t6, t4, 1
    beq t6, zero, panel_off
    addi t1, zero, 35    # '#'
    jal ra, putc
    jal zero, panel_shift
panel_off:
    addi t1, zero, 46    # '.'
    jal ra, putc
panel_shift:
    srli t4, t4, 1
    addi t5, t5, -1
    bne t5, zero, panel_bits
    .emit "]        |\r\n"
    .emit "| OBJ="
    beq s3, s2, panel_a
    addi t1, zero, 66
    jal zero, panel_selection
panel_a:
    addi t1, zero, 65
panel_selection:
    jal ra, putc
    .emit " X="
    lw t4, 0(s3)
    srli t1, t4, 8
    jal ra, hex_nibble
    srli t1, t4, 4
    jal ra, hex_nibble
    addi t1, t4, 0
    jal ra, hex_nibble
    .emit "         |\r\n"
    .emit "| Y="
    lw t4, 4(s3)
    srli t1, t4, 8
    jal ra, hex_nibble
    srli t1, t4, 4
    jal ra, hex_nibble
    addi t1, t4, 0
    jal ra, hex_nibble
    .emit " W="
    lw t4, 8(s3)
    srli t1, t4, 4
    jal ra, hex_nibble
    addi t1, t4, 0
    jal ra, hex_nibble
    .emit "          |\r\n"
    .emit "+---------------------+\r\n"
    jal zero, shell_done


apply_count:
    addi s1, zero, 67
    jal zero, apply
apply_one:
    addi s1, zero, 76
    jal zero, apply
apply:
    sw t4, 0(t0)
    lw t6, 0(t0)
    bne t6, t4, fault
    addi t1, s1, 0
    jal ra, putc
    addi t1, zero, 61
    jal ra, putc
    addi t1, t5, 0
    jal ra, putc
    addi t1, zero, 13
    jal ra, putc
    addi t1, zero, 10
    jal ra, putc
    jal zero, shell_done

query:
    lw t4, 0(t0)
    .emit "M="
    srli t1, t4, 4
    jal ra, hex_nibble
    addi t1, t4, 0
    jal ra, hex_nibble
    .emit "\r\n"
    jal zero, shell_done

invalid:
    .emit "ERR: UNKNOWN\r\r\n"
    jal zero, shell_done
fault:
    .emit "F\r\n"
    jal zero, shell_done

invalid_arg:
    .emit "ERR: ARGUMENT\r\r\n"
    jal zero, shell_done
shell_done:
    addi s7, zero, 0
    addi s11, s8, 0
    jal ra, prompt
    jal zero, poll
prompt:
    addi s5, ra, 0
    .emit "PiKoSoL> "
    jalr zero, 0(s5)

hex_nibble:
    addi s6, ra, 0
    andi t1, t1, 15
    addi t2, t1, -10
    srli t2, t2, 31
    beq t2, zero, hex_letter
    addi t1, t1, 48
    jal ra, putc
    jalr zero, 0(s6)
hex_letter:
    addi t1, t1, 55
    jal ra, putc
    jalr zero, 0(s6)

putc:
    lw t2, 20(t0)
    andi t2, t2, 1
    beq t2, zero, putc
    sw t1, 16(t0)
    jalr zero, 0(ra)
