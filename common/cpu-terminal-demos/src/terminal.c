#include "demos.h"

static int have_color = 0;
static int last_color = -1;
static unsigned int rand_state = 0xACE1U;

void t_putchar(int c)
{
    if (c == '\n') platform_putc('\r');
    platform_putc(c);
}

void t_puts(const char *s)
{
    while (*s) t_putchar((unsigned char)*s++);
}

void t_uint(unsigned long n)
{
    char digits[24];
    unsigned int i = 0;
    do { digits[i++] = (char)('0' + n % 10UL); n /= 10UL; } while (n);
    while (i) t_putchar(digits[--i]);
}

void t_sint(long n)
{
    if (n < 0) {
        t_putchar('-');
        t_uint((unsigned long)(-(n + 1L)) + 1UL);
    } else t_uint((unsigned long)n);
}

void t_hex32(unsigned long n)
{
    const char *dig = "0123456789ABCDEF";
    int i;
    n &= 0xFFFFFFFFUL;
    for (i = 7; i >= 0; --i)
        t_putchar(dig[(unsigned int)((n >> (unsigned int)(i * 4)) & 15UL)]);
}

void t_use_color(int yes)
{
    if (have_color && !yes) t_puts("\033[0m");
    have_color = (yes != 0);
    last_color = -1;
}

void t_color(int id)
{
    if (!have_color || last_color == id) return;
    switch (id) {
    case 1: t_puts("\033[36m"); break;  /* cyan */
    case 2: t_puts("\033[92m"); break;  /* green */
    case 3: t_puts("\033[93m"); break;  /* yellow */
    case 4: t_puts("\033[95m"); break;  /* purple */
    case 5: t_puts("\033[91m"); break;  /* red */
    case 6: t_puts("\033[94m"); break;  /* blue */
    case 7: t_puts("\033[90m"); break;  /* gray */
    default: t_puts("\033[0m"); break;
    }
    last_color = id;
}

void t_clear(void)
{
    if (have_color) t_puts("\033[2J\033[H");
    else t_puts("\n---- FRAME ----\n");
    last_color = -1;
}

int t_read_choice(void)
{
    static int expect_lf = 0;
    int c, answer = 0;
    for (;;) {
        c = platform_getc();
        if (c < 0) return answer ? answer : '0';
        if (expect_lf) {
            expect_lf = 0;
            if (c == '\n') continue; /* CRLF from Windows input */
        }
        if (c == '\r') { expect_lf = 1; return answer; }
        if (c == '\n') return answer;
        if (!answer && c != ' ' && c != '\t') answer = c;
    }
}

void t_wait(void)
{
    t_color(0);
    t_puts("[ENTER] next frame > ");
    (void)t_read_choice();
}

void demo_srand(unsigned int seed)
{
    rand_state = seed ? (seed & 65535U) : 0xACE1U;
}

unsigned int demo_rand(void)
{
    unsigned int bit = ((rand_state >> 0) ^ (rand_state >> 2) ^
        (rand_state >> 3) ^ (rand_state >> 5)) & 1U;
    rand_state = ((rand_state >> 1) | (bit << 15)) & 65535U;
    return rand_state;
}