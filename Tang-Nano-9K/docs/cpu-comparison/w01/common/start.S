/* Identical W01 startup and stack address, no C runtime. MIT. */
.section .text.start, "ax", @progbits
.balign 4
.globl _start
.type _start, @function
_start:
  li sp, 0x80000800
  call main
1: j 1b
