#ifndef KONSOL_DEMOS_H
#define KONSOL_DEMOS_H
/* Cross-CPU Terminal Demos. ISO C90, no malloc, no floating point. */
/* Port ABI: define these two functions for your CPU/board. */
void platform_putc(int ch);
int platform_getc(void);

void t_putchar(int c);
void t_puts(const char *s);
void t_uint(unsigned long n);
void t_sint(long n);
void t_hex32(unsigned long n);
void t_color(int id);
void t_use_color(int yes);
void t_clear(void);
int t_read_choice(void);
void t_wait(void);
unsigned int demo_rand(void);
void demo_srand(unsigned int seed);

/* If interactive != 0, ask for Enter between frames. */
void demo_mandel(void);
void demo_life(int interactive);
void demo_maze(void);
void demo_sort(int interactive);
void demo_cube(int interactive);
void demo_ulam(void);
void demo_cpu_info(void);

#endif