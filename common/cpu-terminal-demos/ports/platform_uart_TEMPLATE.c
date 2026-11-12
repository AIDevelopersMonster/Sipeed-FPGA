/* TEMPLATE ONLY - not compiled until filled for a specific FPGA/CPU SoC.
 * Implement platform_putchar/platform_getc using the target's REAL UART
 * MMIO or BIOS console calls. Never guess peripheral base addresses.
 * You must also provide a valid crt0, stack, initialized .data/.bss,
 * linker memory map and a firmware upload path to run freestanding C.
 */
#include "../src/demos.h"

#if !defined(KONSOL_TARGET_UART_BACKEND_READY)
#error "Replace this template with your target UART adapter"
#endif

void platform_putc(int ch)
{
    /* WAIT until hardware UART TX is ready, then write (unsigned char)ch */
    (void)ch;
}

int platform_getc(void)
{
    /* WAIT for RX ready, then return unsigned byte 0..255 */
    return -1;
}