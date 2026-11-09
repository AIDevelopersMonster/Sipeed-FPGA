/* EX20-05 initial software contract. NOT runnable on factory LiteX ROM.
 * VIDEO_BASE must be supplied by the NEW integrated SoC CSR map.
 * Firmware writes background and moving rectangle through Wishbone MMIO.
 */
#include <stdint.h>
#ifndef VIDEO_BASE
#error "Define VIDEO_BASE from the generated integrated SoC memory map"
#endif
static volatile uint32_t * const video = (volatile uint32_t *)(uintptr_t)VIDEO_BASE;
enum { REG_ID=0, REG_BG=1, REG_XY=2, REG_WH=3, REG_RECT=4, REG_STATUS=5, REG_COMMIT=6 };
static int video_idle(uint32_t limit) {
    while (limit--) if (!(video[REG_STATUS] & 1u)) return 1;
    return 0;
}
int video_demo(void) {
    if (video[REG_ID] != 0x56323031u) return -1;
    for (uint32_t x=0; x<960; x+=20) {
        if (!video_idle(1000000u)) return -2;
        video[REG_BG] = (x & 0x20u) ? 0x102040u : 0x203010u;
        video[REG_XY] = (90u<<16) | x;
        video[REG_WH] = (120u<<16) | 200u;
        video[REG_RECT] = 0x00ff80u;
        video[REG_COMMIT] = 1u;
        if (!video_idle(1000000u)) return -3;
        for (volatile uint32_t pause=0; pause<300000u; ++pause) {}
    }
    return 0;
}
