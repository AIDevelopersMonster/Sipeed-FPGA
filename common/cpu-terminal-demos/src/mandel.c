/* Mandelbrot: fixed point Q10 only, no floating point or libm. */
#include "demos.h"
#define MW 68
#define MH 24
#define SCALE 1024L
#define ITER 32

void demo_mandel(void)
{
    int x, y, n, inside = 0;
    long cr, ci, zr, zi, nre, mag;
    const char *gradient = " .:-=+*#%@";
    int shade, color;
    t_puts("\nMANDELBROT: Q10, 68x24, max 32 iterations\n");
    t_puts("window [-2.25,0.75] x [-1.125,1.125]\n");
    for (y = 0; y < MH; ++y) {
        ci = -1152L + (2304L * (long)y) / (MH - 1);
        for (x = 0; x < MW; ++x) {
            cr = -2304L + (3072L * (long)x) / (MW - 1);
            zr = 0; zi = 0;
            for (n = 0; n < ITER; n++) {
                mag = zr * zr + zi * zi;
                if (mag > 4L * SCALE * SCALE) break;
                nre = (zr * zr - zi * zi) / SCALE + cr;
                zi = (2L * zr * zi) / SCALE + ci;
                zr = nre;
            }
            if (n == ITER) {
                inside++;
                color = 4;
                shade = 9;
            } else {
                color = n < 4 ? 7 : (n < 9 ? 6 : (n < 18 ? 1 : 3));
                shade = n >= ITER ? 9 : (n * 9) / ITER;
            }
            t_color(color);
            t_putchar(gradient[shade]);
        }
        t_color(0);
        t_putchar('\n');
    }
    t_puts("INSIDE PIXELS="); t_uint((unsigned long)inside); t_putchar('\n');
}