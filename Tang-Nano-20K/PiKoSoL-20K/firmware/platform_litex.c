/* RAM-only firmware adapter for EX20-05.16 VexRiscv/LiteX.
 * UART CSR offsets follow the LAB-20.6 report; VERIFY against the actual
 * generated csr.csv before building/booting EX20-05.16.
 * SPDX-License-Identifier: MIT
 */
#include "pikosol_shell.h"
#ifndef PIKOSOL_UART_BASE
#error "Pass -DPIKOSOL_UART_BASE=<verified LiteX uart base>"
#endif
#ifndef PIKOSOL_VIDEO_BASE
#define PIKOSOL_VIDEO_BASE PS_VIDEO_BASE
#endif
#if PIKOSOL_VIDEO_BASE != PS_VIDEO_BASE
#error "v0.1 only targets verified EX20-05.16 V201 video base 0xB1000000"
#endif

static uint32_t rd(void *unused, uint32_t addr) {
    (void)unused; return *(volatile const uint32_t *)(uintptr_t)addr;
}
static void wr(void *unused, uint32_t addr, uint32_t value) {
    (void)unused; *(volatile uint32_t *)(uintptr_t)addr=value;
}
static void tx(void *unused, char ch) {
    (void)unused;
    while (rd(0,PIKOSOL_UART_BASE+0x04u)&1u) {} /* uart_txfull */
    wr(0,PIKOSOL_UART_BASE+0x00u,(uint8_t)ch);  /* uart_rxtx write */
}
static unsigned char rx(void) {
    while (rd(0,PIKOSOL_UART_BASE+0x08u)&1u) {} /* uart_rxempty */
    return (unsigned char)rd(0,PIKOSOL_UART_BASE+0x00u);
}

int main(void) {
    static ps_shell shell;
    const ps_io io = {rd,wr,tx,0,PIKOSOL_VIDEO_BASE,PIKOSOL_UART_BASE};
    ps_init(&shell,&io);
    for (;;) ps_feed(&shell,rx());
}
