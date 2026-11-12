/* Colored 32-column bubble sort and exact operation counts. */
#include "demos.h"
#define SW 32
static unsigned char values[SW];

static void draw_bars(int pass, int interactive)
{
    int x, y;
    if (interactive) t_clear();
    t_puts("BUBBLE SORT 32 ITEMS / PASS ");
    t_uint((unsigned long)pass); t_putchar('\n');
    for (y = 16; y > 0; y--) {
        for (x = 0; x < SW; x++) {
            t_color(values[x] >= y ? (x >= SW-1-pass ? 3 : 2) : 7);
            t_putchar(values[x] >= y ? '#' : '.');
        }
        t_color(0); t_putchar('\n');
    }
}

void demo_sort(int interactive)
{
    int i, j, tmp, sorted = 1;
    unsigned long comparisons = 0UL, swaps = 0UL;
    demo_srand(0xBEEFU);
    for (i = 0; i < SW; i++) values[i] = (unsigned char)(1U + demo_rand()%16U);
    for (i = 0; i < SW-1; i++) {
        for (j = 0; j < SW-1-i; j++) {
            comparisons++;
            if (values[j] > values[j+1]) {
                tmp = values[j]; values[j] = values[j+1]; values[j+1] = (unsigned char)tmp;
                swaps++;
            }
        }
        if (i == 0 || i % 5 == 4 || i == SW-2) {
            draw_bars(i+1, interactive);
            if (interactive && i < SW-2) t_wait();
        }
    }
    for (i = 1; i < SW; i++) if (values[i-1] > values[i]) sorted = 0;
    t_puts("SORTED=");t_puts(sorted ? "YES" : "NO");
    t_puts(" COMPARISONS=");t_uint(comparisons);
    t_puts(" SWAPS=");t_uint(swaps);t_putchar('\n');
}