.section .text.start, "ax", @progbits
.balign 4
.global _start
_start:
  li sp, 0x80000800
  call main
1: j 1b
