OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS
{
  . = 0x40010000;
  .text : { *(.text.start) *(.text*) }
  .rodata ALIGN(4) : { *(.rodata*) }
  .data ALIGN(4) : { *(.data*) }
  .bss (NOLOAD) : { *(.bss*) *(COMMON) }
  /DISCARD/ : { *(.comment) *(.note*) *(.eh_frame*) }
}
ASSERT(SIZEOF(.text) + SIZEOF(.rodata) + SIZEOF(.data) < 0x1000, "Code must stay below snapshot region")