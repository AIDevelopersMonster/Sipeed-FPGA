/* Deterministic depth-first maze, BFS solution. All arrays static. */
#include "demos.h"
#define XN 39
#define YN 19
#define AREA (XN*YN)
#define MAX_OPEN ((AREA+1)/2)
#define MAX_CELLS (((XN-1)/2)*((YN-1)/2))
static unsigned char maze[AREA];
static unsigned short parents[AREA];
static unsigned short queue[MAX_OPEN];
static unsigned short path_stack[MAX_CELLS];
static const int ddx[4] = {0, 2, 0, -2};
static const int ddy[4] = {-2, 0, 2, 0};
static const int ndx[4] = {0, 1, 0, -1};
static const int ndy[4] = {-1, 0, 1, 0};

void demo_maze(void)
{
    int x, y, top, k, start, dir, nx, ny, v, cur;
    int head, tail, root, goal, found = 0, length = 0;
    unsigned int j;
    for (j = 0; j < AREA; j++) { maze[j] = '#'; parents[j] = 65535U; }
    demo_srand(0xACE1U);
    /* Carve on odd coordinates; DFS stack indexes into maze. */
    top = 1; path_stack[0] = (unsigned short)(XN + 1);
    maze[XN + 1] = ' ';
    while (top) {
        cur = path_stack[top - 1]; x = cur % XN; y = cur / XN;
        start = (int)(demo_rand() % 4U);
        found = 0;
        for (k = 0; k < 4; k++) {
            dir = (start + k) & 3;
            nx = x + ddx[dir]; ny = y + ddy[dir];
            if (nx > 0 && nx < XN-1 && ny > 0 && ny < YN-1 && maze[ny*XN+nx] == '#') {
                maze[(y+ddy[dir]/2)*XN+(x+ddx[dir]/2)] = ' ';
                maze[ny*XN+nx] = ' ';
                path_stack[top++] = (unsigned short)(ny*XN+nx);
                found = 1; break;
            }
        }
        if (!found) top--;
    }
    /* Breadth-first shortest path. */
    root = XN + 1; goal = (YN-2)*XN + (XN-2);
    head = 0; tail = 0;
    queue[tail++] = (unsigned short)root; parents[root] = (unsigned short)root;
    while (head < tail) {
        cur = queue[head++];
        if (cur == goal) break;
        x = cur % XN; y = cur / XN;
        for (k = 0; k < 4; k++) {
            nx = x + ndx[k]; ny = y + ndy[k];
            if (nx < 1 || nx >= XN-1 || ny < 1 || ny >= YN-1) continue;
            v = ny*XN+nx;
            if (maze[v] == '#' || parents[v] != 65535U) continue;
            parents[v] = (unsigned short)cur;
            queue[tail++] = (unsigned short)v;
        }
    }
    if (parents[goal] != 65535U) {
        cur = goal;
        while (cur != root) {
            maze[cur] = '*';
            cur = parents[cur]; length++;
        }
        maze[root] = 'S'; maze[goal] = 'E';
    }
    t_puts("\nMAZE 39x19: DFS GENERATION + BFS SHORTEST ROUTE\n");
    for (y = 0; y < YN; y++) {
        for (x = 0; x < XN; x++) {
            int v2 = maze[y*XN+x];
            t_color(v2 == '#' ? 6 : (v2 == '*' ? 3 : (v2 == 'S' || v2 == 'E' ? 2 : 0)));
            t_putchar(v2);
        }
        t_color(0); t_putchar('\n');
    }
    t_puts("SHORTEST PATH STEPS=");t_uint((unsigned long)length);
    t_puts(" / BFS VISITED=");t_uint((unsigned long)tail);t_putchar('\n');
}