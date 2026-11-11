/* LAB-06.1B: minimal, freestanding RV32I CPU execution test.
 * MMIO addresses/bitfields from pinned NEORV32 upstream headers:
 * sw/lib/include/neorv32_uart.h and neorv32_gpio.h.
 * This is NOT a PiKoSoL MMIO compatibility layer.
 * No libc, no interrupts, no SD/flash and no simulation-only UART hack.
 * SPDX-License-Identifier: MIT
 */
#include <stdint.h>

#define REG32(addr) (*(volatile uint32_t *)(addr))
#define UART0_CTRL REG32(0xFFF50000u)
#define UART0_DATA REG32(0xFFF50004u)
#define GPIO_OUT   REG32(0xFFFC0004u)

/* NEORV32 UART: baud = Fclk / (2 * (BAUD_DIV + 1) * prescaler).
 * 27 MHz / (2 * 117) = 115384.6 baud, 0.16% from 115200.
 * UART_CTRL_EN=bit0; PRSC=0; BAUD_DIV=(117-1) in bits [15:6].
 */
#define UART_CTRL_READY (1u << 19)
#define UART_CTRL_VALUE ((116u << 6) | 1u)

static void uart_putc(char c) {
    while ((UART0_CTRL & UART_CTRL_READY) == 0u) {
        /* wait until the single-byte TX FIFO can accept data */
    }
    UART0_DATA = (uint32_t)(uint8_t)c;
}

__attribute__((noreturn))
void main(void) {
    static const char banner[] = "NEORV32 READY\r\n";
    /* Logical GPIO=1 illuminates one of the physically active-low LEDs
     * because the external VHDL wrapper inverts the output on board pins.
     */
    GPIO_OUT = 0x15u;
    UART0_CTRL = UART_CTRL_VALUE;
    for (unsigned i = 0; banner[i] != '\0'; ++i) {
        uart_putc(banner[i]);
    }
    /* Keep the first pattern long enough to cover the UART string. */
    while (UART0_CTRL & (1u << 31)) { /* wait until TX fully drained */ }
    GPIO_OUT = 0x2Au;
    while (1) { __asm__ volatile("nop"); }
}
