/* Deterministic cellular automaton with two planes, zero heap. */
#include "demos.h"
#define LW 44
#define LH 18
static unsigned char current[LH][LW];
static unsigned char future[LH][LW];

static void seed_cell(int y, int x)
{
    if (x >= 0 && x < LW && y >= 0 && y < LH) current[y][x] = 1;
}

static unsigned int count_cells(void)
{
    int x, y;
    unsigned int count = 0;
    for (y = 0; y < LH; y++)
        for (x = 0; x < LW; x++) count += current[y][x];
    return count;
}

static void draw_life(int gen, int interactive)
{
    int x, y;
    if (interactive) t_clear();
    t_puts("GAME OF LIFE / GEN="); t_uint((unsigned long)gen);
    t_puts(" / LIVING="); t_uint((unsigned long)count_cells()); t_putchar('\n');
    for (y = 0; y < LH; ++y) {
        for (x = 0; x < LW; ++x) {
            t_color(current[y][x] ? 2 : 7);
            t_putchar(current[y][x] ? '#' : '.');
        }
        t_color(0); t_putchar('\n');
    }
}

void demo_life(int interactive)
{
    int x, y, dy, dx, n, gen;
    for (y = 0; y < LH; ++y)
        for (x = 0; x < LW; ++x) current[y][x] = 0;
    /* Glider */
    seed_cell(2,3); seed_cell(3,4); seed_cell(4,2); seed_cell(4,3); seed_cell(4,4);
    /* Blinker */
    seed_cell(8,15); seed_cell(8,16); seed_cell(8,17);
    /* R-pentomino */
    seed_cell(10,30); seed_cell(10,31); seed_cell(11,29);
    seed_cell(11,30); seed_cell(12,30);
    for (gen = 0; gen <= 12; ++gen) {
        draw_life(gen,interactive);
        if (gen == 12) break;
        if (interactive) t_wait();
        for (y = 0; y < LH; ++y) for (x = 0; x < LW; ++x) {
            n = 0;
            for (dy = -1; dy <= 1; dy++) for (dx = -1; dx <= 1; dx++) {
                if (dx == 0 && dy == 0) continue;
                if (y+dy>=0 && y+dy<LH && x+dx>=0 && x+dx<LW)
                    n += current[y+dy][x+dx];
            }
            future[y][x] = (unsigned char)(n == 3 || (current[y][x] && n == 2));
        }
        for (y = 0; y < LH; ++y) for (x = 0; x < LW; ++x)
            current[y][x] = future[y][x];
    }
    t_puts("LIFE COMPLETE / final living=");
    t_uint((unsigned long)count_cells()); t_putchar('\n');
}