/* PiKoSoL-20K shell v0.1.0. Portable, freestanding C99; no LiteX headers.
 * Software only. No claim of Tang Nano 20K hardware validation.
 * SPDX-License-Identifier: MIT
 */
#ifndef PIKOSOL_SHELL_H
#define PIKOSOL_SHELL_H
#include <stdint.h>

#define PS_VIDEO_BASE 0xB1000000u
#define PS_VIDEO_ID   0x56323031u
#define PS_LINE_CAP   48u       /* 47 characters + NUL */
#define PS_SCREEN_W   1280u
#define PS_SCREEN_H   720u

typedef struct {
    uint32_t (*read32)(void *context, uint32_t address);
    void (*write32)(void *context, uint32_t address, uint32_t value);
    void (*putc)(void *context, char value);
    void *context;
    uint32_t video_base;
    uint32_t uart_base;
} ps_io;

typedef struct {
    uint16_t x, y, w, h;
    uint32_t rgb;
} ps_object;

typedef struct {
    ps_io io;
    ps_object obj[2];
    uint32_t bg;
    uint32_t detected_id;
    uint8_t selected;          /* 0=A, 1=B */
    uint8_t gfx;               /* 0=UART/TERM, 1=single-rectangle HDMI */
    uint8_t video_ok;
    uint8_t len;
    uint8_t history_len;
    uint8_t ignore_lf;
    char line[PS_LINE_CAP];
    char history[PS_LINE_CAP];
} ps_shell;

void ps_init(ps_shell *shell, const ps_io *io);
void ps_feed(ps_shell *shell, unsigned char c);
void ps_execute(ps_shell *shell, const char *command);
#endif
