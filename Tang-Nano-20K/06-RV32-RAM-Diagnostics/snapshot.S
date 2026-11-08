/* PiKoSoL LAB-20.6 v0.1.0 -- VexRiscv_Min / LiteX factory SoC.
 * RV32I+Zicsr; no C runtime, no stack, no BIOS calls, no Flash writes.
 * Target: execute from SDRAM 0x40010000, store immutable pre-print samples
 *         at SDRAM 0x40011000. Print them only after sampling.
 * 
 * "boot 0x40010000" transfers control permanently: press hardware RESET
 * afterward to return to factory LiteX BIOS.
 */
    .option norvc
    .option norelax
    .option nopic
    .section .text.start,"ax",@progbits
    .globl _start
_start:
    lui  s0, 0xf0003          /* LiteX UART CSR base 0xF0003000 */
    lui  s1, 0x40011          /* Snapshot area 0x40011000    */

    /* Allow the BIOS boot banner to drain through serial TX before reading.
     * Runtime is implementation-dependent; this is a long, finite delay. */
    li   t0, 0x100000
.Ldrain:
    addi t0, t0, -1
    bnez t0, .Ldrain

    /* Write evidence header; all samples are taken BEFORE first putchar. */
    li   t1, 0x504b534c       /* PKSL  (marker as 32-bit word) */
    sw   t1, 0(s1)
    li   t1, 0x0001000b       /* revision 1, 11 sampled registers */
    sw   t1, 4(s1)
    lw   t1, 24(s0)          /* uart_txempty   0xF0003018 */
    sw   t1, 8(s1)
    lw   t1, 4(s0)           /* uart_txfull    0xF0003004 */
    sw   t1, 12(s1)
    lw   t1, 8(s0)           /* uart_rxempty   0xF0003008 */
    sw   t1, 16(s1)
    lw   t1, 12(s0)          /* uart_ev_status 0xF000300C */
    sw   t1, 20(s1)
    lw   t1, 16(s0)          /* uart_ev_pending 0xF0003010 */
    sw   t1, 24(s1)
    lw   t1, 20(s0)          /* uart_ev_enable 0xF0003014 */
    sw   t1, 28(s1)
    lw   t1, 28(s0)          /* uart_rxfull    0xF000301C */
    sw   t1, 32(s1)
    csrr t1, mstatus        /* architecture CSR 0x300 */
    sw   t1, 36(s1)
    csrr t1, mie            /* architecture CSR 0x304 */
    sw   t1, 40(s1)
    csrr t1, 0xbc0          /* LiteX-specific IRQ_MASK */
    sw   t1, 44(s1)
    csrr t1, 0xfc0          /* LiteX-specific IRQ_PENDING */
    sw   t1, 48(s1)
    li   t1, 0x454e4f44     /* "DONE" as little-endian bytes */
    sw   t1, 52(s1)

    /* From here on, writes to UART TX are allowed. Print first,
     * then measure txempty for a second, controlled post-print sample. */
    la   a0, banner
    jal  ra, print_string
    lw   t1, 24(s0)         /* txempty AFTER printing banner */
    sw   t1, 56(s1)         /* second sample at 0x40011038 */

    la   s2, label_table
    li   s3, 11
    addi s4, s1, 8
.Lresults:
    lw   a0, 0(s2)          /* absolute pointer to label, linked to 0x40010000 */
    jal  ra, print_string
    lw   a0, 0(s4)          /* recorded value, not a fresh CSR read */
    jal  ra, print_hex32
    la   a0, newline
    jal  ra, print_string
    addi s2, s2, 4
    addi s4, s4, 4
    addi s3, s3, -1
    bnez s3, .Lresults

    la   a0, post_label
    jal  ra, print_string
    lw   a0, 56(s1)
    jal  ra, print_hex32
    la   a0, newline
    jal  ra, print_string

    la   a0, footer
    jal  ra, print_string
.Lhold:
    j .Lhold                /* Factory Flash preserved. Press hardware RESET. */

/* UART txfull==0 -> space in TX FIFO; poll before each write. */
uart_putchar:
.Lwait_tx:
    lw   t6, 4(s0)
    bnez t6, .Lwait_tx
    sw   a0, 0(s0)          /* UART rxtx write-only use */
    ret

/* a0 -> zero-terminated SDRAM string. s8 is a private return holder. */
print_string:
    mv   s8, ra
    mv   t0, a0
.Lstring_loop:
    lbu  a0, 0(t0)
    beqz a0, .Lstring_done
    jal  ra, uart_putchar
    addi t0, t0, 1
    j .Lstring_loop
.Lstring_done:
    jr   s8

/* a0 = u32 -> eight uppercase hexadecimal digits. */
print_hex32:
    mv   s9, ra
    mv   t3, a0
    li   t4, 8
.Lhex_loop:
    srli t5, t3, 28
    li   t6, 10
    bltu t5, t6, .Ldigit
    addi a0, t5, 55          /* ASCII 'A' - 10 */
    j .Lemit_hex
.Ldigit:
    addi a0, t5, 48          /* ASCII '0' */
.Lemit_hex:
    jal  ra, uart_putchar
    slli t3, t3, 4
    addi t4, t4, -1
    bnez t4, .Lhex_loop
    jr   s9

    .section .rodata,"a",@progbits
    .p2align 2
banner:  .asciz "\r\nPiKoSoL LAB20.6 RAM-only snapshot BEFORE UART output\r\n"
newline: .asciz "\r\n"
post_label: .asciz "TXEMPTY_AFTER_PRINT = 0x"
footer:  .asciz "LAB20.6 HOLD - press physical RESET to return to BIOS\r\n"
name_0:  .asciz "TXEMPTY    = 0x"
name_1:  .asciz "TXFULL     = 0x"
name_2:  .asciz "RXEMPTY    = 0x"
name_3:  .asciz "EV_STATUS  = 0x"
name_4:  .asciz "EV_PENDING = 0x"
name_5:  .asciz "EV_ENABLE  = 0x"
name_6:  .asciz "RXFULL     = 0x"
name_7:  .asciz "MSTATUS    = 0x"
name_8:  .asciz "MIE        = 0x"
name_9:  .asciz "IRQ_MASK   = 0x"
name_10: .asciz "IRQ_PENDING= 0x"
    .p2align 2
label_table:
    .word name_0, name_1, name_2, name_3, name_4, name_5
    .word name_6, name_7, name_8, name_9, name_10