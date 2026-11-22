/* PiKoSoL TP20 / Dock V3714 / PicoRV32 — MMIO educational example.
 * Demonstrates the exact register contract, NOT a board-verified C binary.
 * Compile for the actual PiKoSoL PKD1 app ABI only after linking/ABI verification.
 * Source for the real board-tested BINs is in ../tools/*.py.
 */
#include <stdint.h>

#define MMIO32(addr) (*(volatile uint32_t *)(uintptr_t)(addr))
#define P0_OUT    0x80000000u
#define P0_IN     0x80000004u
#define P1_OUT    0x80000020u
#define P1_IN     0x80000024u
#define P1_DIR    0x80000028u
#define P2_OUT    0x80000030u
#define P2_IN     0x80000034u
#define P2_DIR    0x80000038u
#define P3_OUT    0x80000040u
#define P3_IN     0x80000044u
#define P3_DIR    0x80000048u
#define LED_OUT   0x80000050u
#define KEY_IN    0x80000054u
#define DIP_RAW   0x80000058u
#define GPIO_ID   0x8000005Cu
#define GP14      0x47503134u

static void pmod123_write(uint32_t out_addr, uint8_t mask) {
    MMIO32(out_addr + 8u) = 0u;       /* DIR=0: release output drivers */
    MMIO32(out_addr) = 0xffu;         /* active-LOW LEDx8: all off */
    MMIO32(out_addr + 8u) = 0xffu;    /* all eight pins now outputs */
    MMIO32(out_addr) = mask;          /* a zero bit lights that LED */
}

void pmod_demo(void) {
    if (MMIO32(GPIO_ID) != GP14) return;
    /* PMOD0 is inverted in the RTL: writing 1 lights a LEDx8 bit. */
    MMIO32(P0_OUT) = 0x01u;
    /* PMOD1,2,3 drive their pins directly: writing 0 lights a bit. */
    pmod123_write(P1_OUT, 0xfeu);
    pmod123_write(P2_OUT, 0xfdu);
    pmod123_write(P3_OUT, 0xfbu);
    /* These are digital readback values, not optical LED measurements. */
    volatile uint32_t sample = MMIO32(P1_IN) | (MMIO32(P2_IN) << 8);
    (void)sample;
}

void pmod_all_off(void) {
    if (MMIO32(GPIO_ID) != GP14) return;
    MMIO32(LED_OUT) = 0u;       /* six on-board LEDs: 0=off */
    MMIO32(P0_OUT) = 0u;        /* PMOD0 inverted pads -> LED module off */
    uint32_t ports[3] = {P1_OUT, P2_OUT, P3_OUT};
    for (unsigned i = 0; i < 3; ++i) {
        MMIO32(ports[i] + 8u) = 0u;    /* Hi-Z */
        MMIO32(ports[i]) = 0xffu;      /* safe off output latch */
    }
}
