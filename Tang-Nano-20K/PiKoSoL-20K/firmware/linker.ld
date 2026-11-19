/* PROVISIONAL SDRAM map, must be verified on EX20-05.16 before loading.
 * 0x40010000: code/data. 0x4001C000..0x4001FFFF: reserved for stack.
 */
OUTPUT_ARCH(riscv)
ENTRY(_start)
SECTIONS {
    . = 0x40010000;
    .text : { KEEP(*(.text.start)) *(.text*) }
    .rodata ALIGN(4) : { *(.rodata*) *(.srodata*) }
    .data ALIGN(4) : { *(.data*) *(.sdata*) }
    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*) *(.sbss*) *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    }
    __image_end = .;
    __stack_top = 0x40020000;
    /DISCARD/ : { *(.comment*) *(.note*) *(.eh_frame*) }
}
ASSERT(__image_end < 0x4001C000, "PiKoSoL image overlaps reserved stack area")
