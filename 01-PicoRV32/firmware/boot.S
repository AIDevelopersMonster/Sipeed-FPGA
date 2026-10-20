# Sipeed-FPGA LAB-02: UART RX -> PicoRV32 -> MMIO LEDs -> UART TX ACK
# RV32I only; no stack, RAM, C runtime or interrupts.
# 27 MHz, 115200 baud, 8N1; Tang Nano 9K integrated USB serial bridge.
# GPIO state is exclusively controlled by this firmware (no timer animation).
.text
.globl _start
_start:
    lui t0, 0x20000
    sw zero, 0(t0)         # LED reset
    # An initial banner distinguishes LAB-02 from the older 'PICO' firmware.
    addi t1, zero, 82      # R
    jal ra, putc
    addi t1, zero, 69      # E
    jal ra, putc
    addi t1, zero, 65      # A
    jal ra, putc
    addi t1, zero, 68      # D
    jal ra, putc
    addi t1, zero, 89      # Y
    jal ra, putc
    addi t1, zero, 10      # newline
    jal ra, putc

poll:
    lw t2, 28(t0)          # UART_RX_STATUS bit0 = FIFO not empty
    andi t2, t2, 1
    beq t2, zero, poll
    lw t3, 24(t0)          # UART_RX_DATA, consumes a byte

    addi s0, zero, 63      # '?': read current hardware LED register
    beq t3, s0, query
    addi s0, zero, 48      # '0'
    beq t3, s0, select0
    addi s0, zero, 49
    beq t3, s0, select1
    addi s0, zero, 50
    beq t3, s0, select2
    addi s0, zero, 51
    beq t3, s0, select3
    addi s0, zero, 52
    beq t3, s0, select4
    addi s0, zero, 53
    beq t3, s0, select5
    addi s0, zero, 54
    beq t3, s0, select6
    addi s0, zero, 10      # ignore CR / LF from ordinary terminals
    beq t3, s0, poll
    addi s0, zero, 13
    beq t3, s0, poll
    jal zero, invalid

select0:
    addi t4, zero, 0
    addi t5, zero, 48
    jal zero, apply
select1:
    addi t4, zero, 1
    addi t5, zero, 49
    jal zero, apply
select2:
    addi t4, zero, 2
    addi t5, zero, 50
    jal zero, apply
select3:
    addi t4, zero, 4
    addi t5, zero, 51
    jal zero, apply
select4:
    addi t4, zero, 8
    addi t5, zero, 52
    jal zero, apply
select5:
    addi t4, zero, 16
    addi t5, zero, 53
    jal zero, apply
select6:
    addi t4, zero, 32
    addi t5, zero, 54
    jal zero, apply

apply:
    sw t4, 0(t0)           # actual physical MMIO write
    lw t6, 0(t0)           # readback: must match before sending ACK
    bne t6, t4, fault
    jal zero, acknowledge

query:
    lw t6, 0(t0)           # hardware state, not a cached command
    addi s0, zero, 0
    beq t6, s0, q0
    addi s0, zero, 1
    beq t6, s0, q1
    addi s0, zero, 2
    beq t6, s0, q2
    addi s0, zero, 4
    beq t6, s0, q3
    addi s0, zero, 8
    beq t6, s0, q4
    addi s0, zero, 16
    beq t6, s0, q5
    addi s0, zero, 32
    beq t6, s0, q6
    jal zero, fault
q0:
    addi t5, zero, 48
    jal zero, acknowledge
q1:
    addi t5, zero, 49
    jal zero, acknowledge
q2:
    addi t5, zero, 50
    jal zero, acknowledge
q3:
    addi t5, zero, 51
    jal zero, acknowledge
q4:
    addi t5, zero, 52
    jal zero, acknowledge
q5:
    addi t5, zero, 53
    jal zero, acknowledge
q6:
    addi t5, zero, 54
    jal zero, acknowledge

acknowledge:
    # Literal wire protocol L=<0..6>\n. ACK means LED MMIO was read back.
    addi t1, zero, 76      # L
    jal ra, putc
    addi t1, zero, 61      # =
    jal ra, putc
    addi t1, t5, 0        # selected digit
    jal ra, putc
    addi t1, zero, 10
    jal ra, putc
    jal zero, poll

invalid:
    # Incorrect command: no change to LEDs, report E\n.
    addi t1, zero, 69
    jal ra, putc
    addi t1, zero, 10
    jal ra, putc
    jal zero, poll

fault:
    # Readback did not match. Do not report a false successful write.
    addi t1, zero, 70      # F
    jal ra, putc
    addi t1, zero, 10
    jal ra, putc
    jal zero, poll

putc:
    lw t2, 20(t0)          # UART_STATUS (TX ready = bit0)
    andi t2, t2, 1
    beq t2, zero, putc
    sw t1, 16(t0)          # UART_TX; stalls if busy
    jalr zero, 0(ra)
