/* Minimal fixed-board lab linker map. No runtime, heap or initialized globals.
 * SPDX-License-Identifier: MIT
 */
OUTPUT_FORMAT("elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
    rom (rx)  : ORIGIN = 0x00000000, LENGTH = 16K
    ram (rwx) : ORIGIN = 0x80000000, LENGTH = 2K
}
SECTIONS {
  .text : ALIGN(4) {
      KEEP(*(.text.start))
      *(.text .text.*)
      *(.rodata .rodata.*)
      . = ALIGN(4);
  } > rom
  .data : ALIGN(4) {
      *(.data .data.*)
      *(.sdata .sdata.*)
      . = ALIGN(4);
  } > ram AT > rom
  .bss (NOLOAD) : ALIGN(4) {
      *(.bss .bss.*)
      *(COMMON)
      . = ALIGN(4);
  } > ram
  /DISCARD/ : { *(.comment) *(.eh_frame) *(.note*) }
}
