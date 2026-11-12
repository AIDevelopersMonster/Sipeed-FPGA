/* Integer-only 3D cube, 16 deterministic frames, Bresenham edges. */
#include "demos.h"
#define CW 65
#define CH 23
static char screen[CH][CW];
static int px[8], py[8];
static const int sins[16] = {
     0,98,181,237,256,237,181,98,
     0,-98,-181,-237,-256,-237,-181,-98
};
static const int edges[12][2] = {
    {0,1},{1,3},{3,2},{2,0},
    {4,5},{5,7},{7,6},{6,4},
    {0,4},{1,5},{2,6},{3,7}
};

static int positive_abs(int n) { return n < 0 ? -n : n; }

static void line2d(int x0, int y0, int x1, int y1, char c)
{
    int dx = positive_abs(x1-x0), sx = x0 < x1 ? 1 : -1;
    int dy = -positive_abs(y1-y0), sy = y0 < y1 ? 1 : -1;
    int err = dx+dy, e2;
    for (;;) {
        if (x0 >= 0 && x0 < CW && y0 >= 0 && y0 < CH) screen[y0][x0] = c;
        if (x0 == x1 && y0 == y1) break;
        e2 = 2*err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}

void demo_cube(int interactive)
{
    int frame, x, y, j, angle, sa, ca, sb, cb;
    int vx, vy, vz, rx, ry, rz, rz2;
    long tempx, tempy;
    char c;
    for (frame = 0; frame < 16; frame++) {
        angle = frame & 15;
        sa = sins[angle]; ca = sins[(angle+4)&15];
        sb = sins[(frame*2)&15]; cb = sins[(frame*2+4)&15];
        for (j = 0; j < 8; j++) {
            vx = (j & 1) ? 16 : -16;
            vy = (j & 2) ? 11 : -11;
            vz = (j & 4) ? 15 : -15;
            rx = (int)(((long)vx*ca+(long)vz*sa)/256L);
            rz = (int)((-(long)vx*sa+(long)vz*ca)/256L);
            ry = (int)(((long)vy*cb-(long)rz*sb)/256L);
            rz2 = (int)(((long)vy*sb+(long)rz*cb)/256L);
            tempx = (long)rx*95L/(85L+rz2);
            tempy = (long)ry*52L/(85L+rz2);
            px[j] = CW/2+(int)tempx;
            py[j] = CH/2+(int)tempy;
        }
        for (y = 0; y < CH; y++)
            for (x = 0; x < CW; x++) screen[y][x] = ' ';
        for (j = 0; j < 12; j++) {
            c = j < 4 ? '#' : (j < 8 ? '+' : '|');
            line2d(px[edges[j][0]],py[edges[j][0]],
                    px[edges[j][1]],py[edges[j][1]],c);
        }
        for (j = 0; j < 8; j++) {
            if (px[j]>=0 && px[j]<CW && py[j]>=0 && py[j]<CH)
                screen[py[j]][px[j]]='O';
        }
        if (interactive) t_clear();
        t_puts("3D CUBE / INTEGER FIXED ROTATIONS / FRAME=");
        t_uint((unsigned long)(frame+1)); t_puts("/16\n");
        for (y = 0; y < CH; y++) {
            for (x = 0; x < CW; x++) {
                c = screen[y][x];
                t_color(c=='O' ? 4 : (c=='#' ? 3 : (c=='+' ? 1 : (c=='|' ? 2 : 0))));
                t_putchar(c);
            }
            t_color(0);t_putchar('\n');
        }
        if (interactive && frame < 15) t_wait();
    }
    t_puts("CUBE FRAMES=16\n");
}