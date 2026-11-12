/* Host or target with working stdio (e.g. a C runtime connected to UART). */
#include <stdio.h>
#ifdef _WIN32
#include <fcntl.h>
#include <io.h>
#endif

void platform_host_init(void)
{
#ifdef _WIN32
    /* Prevent Windows CRT from duplicating our explicit CRLF. */
    _setmode(_fileno(stdout), _O_BINARY);
    _setmode(_fileno(stdin), _O_BINARY);
#endif
}

void platform_putc(int ch) { (void)putchar(ch); }
int platform_getc(void) { (void)fflush(stdout); return getchar(); }