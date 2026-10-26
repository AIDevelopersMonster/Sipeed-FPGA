OUTPUT_FORMAT("elf32-littleriscv")
OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY {
  rom (rx) : ORIGIN = 0x00000000, LENGTH = 16K
  ram (rw) : ORIGIN = 0x80000000, LENGTH = 2K
}
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text .text.*) *(.rodata .rodata.*) *(.srodata .srodata.*) . = ALIGN(4); } > rom
 .data : { *(.data .data.*) *(.sdata .sdata.*) . = ALIGN(4); } > ram AT > rom
 .bss (NOLOAD) : { *(.bss .bss.*) *(COMMON) . = ALIGN(4); } > ram
 /DISCARD/ : { *(.comment) *(.eh_frame) *(.note*) }
}
ASSERT(SIZEOF(.data) == 0, "No initialized data supported in LAB062")
ASSERT(SIZEOF(.bss) == 0, "No BSS startup implemented in LAB062")
