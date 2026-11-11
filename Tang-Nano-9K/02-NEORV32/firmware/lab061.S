/* LAB-06.1B: smallest RV32I entry; no C runtime or external Flash.
 * IMEM begins at address zero, DMEM is 0x80000000..0x800007ff.
 * This program does not need global-pointer/data/BSS initialization.
 * SPDX-License-Identifier: MIT
 */
.section .text.start, "ax", @progbits
.balign 4
.global _start
.type _start, @function
_start:
    li sp, 0x80000800
    call main
.Lhalt:
    j .Lhalt
