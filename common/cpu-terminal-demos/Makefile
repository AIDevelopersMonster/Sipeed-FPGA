CC ?= cc
CFLAGS ?= -O2 -Wall -Wextra -pedantic -std=c90
FILES = src/main.c src/terminal.c src/platform_stdio.c src/mandel.c src/life.c src/maze.c src/sort.c src/cube.c src/ulam.c src/cpuinfo.c

.PHONY: all clean quick-check
all: demos

demos: $(FILES) src/demos.h
	$(CC) $(CFLAGS) -o $@ $(FILES)

quick-check: demos
	./demos --plain --demo 7
	./demos --plain --demo 3 | tail -n 1
	./demos --plain --demo 4 | tail -n 1

clean:
	rm -f demos