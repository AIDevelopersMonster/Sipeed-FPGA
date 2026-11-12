#include "demos.h"
#ifndef DEMO_FREESTANDING
#include <string.h>
void platform_host_init(void);
#endif

static void dispatch(int c, int interactive)
{
    switch (c) {
    case '1': demo_mandel(); break;
    case '2': demo_life(interactive); break;
    case '3': demo_maze(); break;
    case '4': demo_sort(interactive); break;
    case '5': demo_cube(interactive); break;
    case '6': demo_ulam(); break;
    case '7': demo_cpu_info(); break;
    default: t_puts("Unknown selection\n"); break;
    }
    t_color(0);
}

static void menu(void)
{
    int choice;
    for (;;) {
        t_color(0);
        t_puts("\nKONSOL CROSS-CPU TERMINAL DEMOS 0.1\n");
        t_puts("1 Mandelbrot Q10 fixed point\n");
        t_puts("2 Conway Life (step by Enter)\n");
        t_puts("3 Maze generation + BFS route\n");
        t_puts("4 Bubble sorting bars\n");
        t_puts("5 Rotating 3D wire cube\n");
        t_puts("6 Ulam prime spiral\n");
        t_puts("7 CPU / integer / CRC32\n");
        t_puts("8 Toggle ANSI color\n");
        t_puts("0 Exit\nSELECT 0-8 > ");
        choice = t_read_choice();
        if (choice == '0') break;
        if (choice == '8') {
            static int colors = 1;
            colors = !colors;
            t_use_color(colors);
            t_puts(colors ? "Color ON\n" : "Color OFF\n");
        } else dispatch(choice, 1);
    }
    t_color(0);
    t_puts("END\n");
}

#ifdef DEMO_FREESTANDING
int main(void)
{
    t_use_color(1);
    menu();
    return 0;
}
#else
int main(int argc, char **argv)
{
    int i, plain = 0, all = 0, choice = 0;
    platform_host_init();
    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--plain") == 0) plain = 1;
        else if (strcmp(argv[i], "--all") == 0) all = 1;
        else if (strcmp(argv[i], "--demo") == 0 && i + 1 < argc)
            choice = (unsigned char)argv[++i][0];
        else {
            t_puts("Usage: demos [--plain] [--all | --demo N] (N=1..7)\n");
            return 2;
        }
    }
    t_use_color(!plain);
    if (all) {
        for (i = '1'; i <= '7'; i++) dispatch(i, 0);
    } else if (choice) {
        dispatch(choice, 0);
    } else menu();
    return 0;
}
#endif