/* Ulam prime spiral, integer primality, 31x31. */
#include "demos.h"
#define UN 31
static char ulam[UN][UN];
static const int udx[4] = {1,0,-1,0};
static const int udy[4] = {0,-1,0,1};

static int is_prime(int n)
{
    int d;
    if (n < 2) return 0;
    for (d = 2; d*d <= n; d++) if (n % d == 0) return 0;
    return 1;
}

void demo_ulam(void)
{
    int x = UN/2, y = UN/2, n = 1, count = 0;
    int step = 1, dir = 0, r, j, k, px, py, p;
    char c;
    for (r = 0; r < UN; ++r)
        for (j = 0; j < UN; j++) ulam[r][j] = ' ';
    ulam[y][x] = '1';
    while (n < UN*UN) {
        for (k = 0; k < 2; k++) {
            for (j = 0; j < step && n < UN*UN; j++) {
                x += udx[dir]; y += udy[dir]; n++;
                if (x < 0 || x >= UN || y < 0 || y >= UN) continue;
                p = is_prime(n);
                ulam[y][x] = p ? '#' : '.';
                count += p;
            }
            dir = (dir+1)&3;
        }
        step++;
    }
    t_puts("\nULAM PRIME SPIRAL 31x31 (primes=#, others=.)\n");
    for (py=0; py<UN; py++) {
        for (px=0; px<UN; px++) {
            c=ulam[py][px];
            t_color(c=='#' ? 2 : (c=='1' ? 4 : 7));
            t_putchar(c);
        }
        t_color(0);t_putchar('\n');
    }
    t_puts("PRIMES SHOWN=");t_uint((unsigned long)count);t_putchar('\n');
}