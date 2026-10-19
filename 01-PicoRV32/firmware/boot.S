# Tiny RV32I program for the stage P1 board-independent MMIO contract.
# Uses no assembler macros, C runtime, interrupt handler, or RAM stack.
# Boot at physical 0x00000000, MMIO base 0x20000000.
.text
.globl _start
_start:
    lui  t0, 0x20000
    addi t1, zero, 21
    sw   t1, 0(t0)          # set LED pattern
    lw   t2, 8(t0)          # device signature
    lui  t3, 0x5a5a0
    addi t3, t3, 1
    bne  t2, t3, failed

    addi t1, zero, 80       # P
    jal  ra, putc
    addi t1, zero, 73       # I
    jal  ra, putc
    addi t1, zero, 67       # C
    jal  ra, putc
    addi t1, zero, 79       # O
    jal  ra, putc
    addi t1, zero, 10       # LF
    jal  ra, putc

    lui  t2, 0x600dd       # 0x600DCAFE = 0x600DD000 - 0x502
    addi t2, t2, -1282
    sw   t2, 12(t0)         # completion marker, not a real board measurement

loop:
    lw   t4, 4(t0)          # hardware free-running cycle counter
    srli t4, t4, 20
    andi t4, t4, 63
    sw   t4, 0(t0)          # animation from hardware cycles
    jal  zero, loop

putc:
    lw   t2, 20(t0)         # UART_STATUS
    andi t2, t2, 1
    beq  t2, zero, putc
    sw   t1, 16(t0)         # UART_TX
    jalr zero, 0(ra)

failed:
    addi t1, zero, 63
    sw   t1, 0(t0)
    jal  zero, failed
