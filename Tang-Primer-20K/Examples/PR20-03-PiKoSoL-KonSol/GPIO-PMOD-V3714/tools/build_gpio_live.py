#!/usr/bin/env python3
"""PiKoSoL TP20 GPIO live (5s): keys+DIP -> 6 LEDs + HDMI + UART.
Pure RV32I PKD1 builder. No GCC, no FPGA programming, no Flash.
Requires the operator's GPIO V3714 .fs and PiKoSoL monitor.
"""
from __future__ import annotations

import argparse
import hashlib
from pathlib import Path
import struct

MAGIC = 0x31444B50
ENTRY = 0x2000C010
VRAM = 0x30000000
LED_REG = 0x80000050
UART_DATA = 0x8000000C
GPIO_ID = 0x47503134
SCREEN_WIDTH = 96
DURATION_CYCLES = 300_000_000  # 5 seconds at the stock TP20 ~60 MHz
DEBOUNCE_CYCLES = 1_200_000  # about 20ms
FG_AQUA, FG_LIME, FG_YELLOW, FG_WHITE, BG_NAVY = 14, 10, 11, 15, 4


def sign12(i):
    assert -2048 <= i <= 2047, i
    return i & 4095


def lui(rd, n):
    assert 0 <= n < (1 << 20)
    return (n << 12) | (rd << 7) | 0x37


def addi(rd, rs, i):
    return (sign12(i) << 20) | (rs << 15) | (rd << 7) | 0x13


def andi(rd, rs, i):
    return (sign12(i) << 20) | (rs << 15) | (7 << 12) | (rd << 7) | 0x13


def srli(rd, rs, shift):
    assert 0 <= shift <= 31
    return (shift << 20) | (rs << 15) | (5 << 12) | (rd << 7) | 0x13


def slli(rd, rs, shift):
    assert 0 <= shift <= 31
    return (shift << 20) | (rs << 15) | (1 << 12) | (rd << 7) | 0x13


def sub(rd, a, b):
    return (0x20 << 25) | (b << 20) | (a << 15) | (rd << 7) | 0x33


def orr(rd, a, b):
    return (b << 20) | (a << 15) | (6 << 12) | (rd << 7) | 0x33


def lw(rd, base, off):
    assert off % 4 == 0
    return (sign12(off) << 20) | (base << 15) | (2 << 12) | (rd << 7) | 3


def sw(rs, base, off):
    u = sign12(off)
    return ((u >> 5) << 25) | (rs << 20) | (base << 15) | (2 << 12) | ((u & 31) << 7) | 0x23


def branch(a, b, distance, funct3):
    assert distance % 2 == 0 and -4096 <= distance < 4096, distance
    v = distance & 8191
    return (((v >> 12) & 1) << 31) | (((v >> 5) & 63) << 25) | (b << 20) | (a << 15) | (funct3 << 12) | (((v >> 1) & 15) << 8) | (((v >> 11) & 1) << 7) | 0x63


def jal_zero(distance):
    assert distance % 2 == 0 and -(1 << 20) <= distance < (1 << 20)
    v = distance & 0x1FFFFF
    return (((v >> 20) & 1) << 31) | (((v >> 1) & 1023) << 21) | (((v >> 11) & 1) << 20) | (((v >> 12) & 255) << 12) | 0x6F


def rdcycle(rd):
    return (0xC00 << 20) | (2 << 12) | (rd << 7) | 0x73


def ret():
    return 0x00008067


class Code:
    def __init__(self):
        self.words = []
        self.labels = {}
        self.fixups = []

    def emit(self, *words):
        self.words.extend(words)

    def label(self, name):
        assert name not in self.labels, name
        self.labels[name] = len(self.words)

    def br(self, kind, a, b, to):
        self.fixups.append((len(self.words), kind, a, b, to))
        self.emit(0)

    def jump(self, to):
        self.br('j', 0, 0, to)

    def imm(self, rd, value):
        value &= 0xFFFFFFFF
        hi = ((value + 0x800) >> 12) & 0xFFFFF
        lo = (value - (hi << 12)) & 0xFFFFFFFF
        if lo >= 0x80000000:
            lo -= 0x100000000
        self.emit(lui(rd, hi), addi(rd, rd, lo))

    def screen_text(self, row, col, message, fg=FG_WHITE, bg=BG_NAVY):
        assert all(32 <= ord(c) < 127 for c in message)
        assert 0 <= row < 42 and 0 <= col and col + len(message) <= SCREEN_WIDTH
        self.imm(6, VRAM + 4 * (row * SCREEN_WIDTH + col))
        self.imm(28, (fg << 24) | (bg << 16))
        for index, ch in enumerate(message):
            self.emit(addi(30, 28, ord(ch)), sw(30, 6, 4 * index))

    def send_uart(self, message):
        for ch in message:
            self.emit(addi(30, 0, ord(ch)), sw(30, 29, 0))

    def bit_to_ascii(self, src, bit):
        self.emit(srli(30, src, bit), andi(30, 30, 1), addi(30, 30, 48))

    def dynamic_hdmi(self, row, column_bits, src):
        self.imm(6, VRAM + 4 * (row * SCREEN_WIDTH))
        self.imm(28, (FG_LIME << 24) | (BG_NAVY << 16))
        for col, bit in column_bits:
            self.bit_to_ascii(src, bit)
            self.emit(orr(30, 30, 28), sw(30, 6, col * 4))

    def uart_bits(self, label, src, bits):
        self.send_uart(label)
        for bit in bits:
            self.bit_to_ascii(src, bit)
            self.emit(sw(30, 29, 0))

    def finish(self):
        for where, kind, a, b, dest in self.fixups:
            assert dest in self.labels, dest
            offset = 4 * (self.labels[dest] - where)
            if kind == 'j':
                self.words[where] = jal_zero(offset)
            else:
                self.words[where] = branch(a, b, offset, {'beq': 0, 'bne': 1, 'bltu': 6, 'bgeu': 7}[kind])
        assert self.words[-1] == ret()
        return struct.pack('<' + 'I' * len(self.words), *self.words)


def program():
    c = Code()
    c.imm(5, LED_REG)   # x5: GPIO_LED base, +4 keys, +8 DIP, +12 ID
    c.imm(29, UART_DATA)  # x29: serial output (already configured by monitor)
    c.emit(lw(30, 5, 12))
    c.imm(28, GPIO_ID)
    c.br('beq', 30, 28, 'id_ok')
    c.screen_text(4, 4, 'GPIO ID MISMATCH: EXPECT GP14, NO LED WRITES', FG_YELLOW)
    c.send_uart('[GPIO ERROR: GPIO_ID != GP14; no LED writes]\r\n')
    c.emit(ret())
    c.label('id_ok')

    c.screen_text(2, 4, 'PiKoSoL TP20 | GPIO LIVE | PicoRV32 / RV32I', FG_YELLOW)
    c.screen_text(4, 4, 'KEY S2=0 S3=0 S5=0 (1=PRESSED)')
    c.screen_text(6, 4, 'DIP SW2=0 SW3=0 SW4=0 SW5=0 (RAW INPUT)')
    c.screen_text(8, 4, 'LED 0 1 2 3 4 5 : 0 0 0 0 0 0 (1=ON)')
    c.screen_text(11, 4, 'LED0..2 <- S2,S3,S5 | LED3..5 <- SW2,SW3,SW4', FG_AQUA)
    c.screen_text(13, 4, 'SW5 is displayed but does not drive a discrete LED.', FG_AQUA)
    c.screen_text(15, 4, 'Inputs shown LIVE for 5 seconds, then RUN returns.', FG_YELLOW)
    c.screen_text(17, 4, 'LEDs hold last state. Repeat RUN for another 5s.', FG_YELLOW)
    c.screen_text(19, 4, 'UART: state lines on COM port / File Manager log.', FG_AQUA)
    c.screen_text(21, 4, 'No FPGA Flash, no new FPGA bitstream, no PMOD writes.')
    c.send_uart('\r\n[PiKoSoL GPIO LIVE 5s] Keys + DIP -> 6 LEDs / HDMI / UART\r\n')

    # x10 start, x11 now, x12 raw combined, x13 candidate, x14 stable,
    # x15 candidate since, x16 keys, x17 DIP, x7 debounce ticks, x31 total ticks.
    c.imm(31, DURATION_CYCLES)
    c.imm(7, DEBOUNCE_CYCLES)
    c.emit(rdcycle(10), addi(13, 0, -1), addi(14, 0, -1), addi(15, 10, 0))
    c.label('sample')
    c.emit(rdcycle(11), sub(30, 11, 10))
    c.br('bgeu', 30, 31, 'done')
    c.emit(lw(16, 5, 4), lw(17, 5, 8), andi(16, 16, 7), andi(17, 17, 15), slli(12, 17, 3), orr(12, 12, 16))
    c.br('beq', 12, 13, 'candidate_same')
    c.emit(addi(13, 12, 0), addi(15, 11, 0))
    c.jump('sample')
    c.label('candidate_same')
    c.br('beq', 12, 14, 'sample')
    c.emit(sub(30, 11, 15))
    c.br('bltu', 30, 7, 'sample')
    c.emit(addi(14, 12, 0), andi(28, 12, 63), sw(28, 5, 0))

    # Draw only changing values; rest of the monitor's HDMI remains untouched.
    # Avoid overwriting callee-saved registers x8/x9/x18..x27 or x1/ra.
    keyline = 'KEY S2=0 S3=0 S5=0 (1=PRESSED)'
    dipline = 'DIP SW2=0 SW3=0 SW4=0 SW5=0 (RAW INPUT)'
    ledline = 'LED 0 1 2 3 4 5 : 0 0 0 0 0 0 (1=ON)'
    def columns(line, keys):
        return [(4 + line.index(key) + len(key), bit) for bit, key in enumerate(keys)]
    c.dynamic_hdmi(4, columns(keyline, ['S2=', 'S3=', 'S5=']), 16)
    c.dynamic_hdmi(6, columns(dipline, ['SW2=', 'SW3=', 'SW4=', 'SW5=']), 17)
    offset = ledline.index(': ') + 2
    c.dynamic_hdmi(8, [(4 + offset + 2 * bit, bit) for bit in range(6)], 12)

    # UART is one event line per debounced state change, not a flood of samples.
    c.send_uart('GPIO S2=')
    c.bit_to_ascii(16, 0); c.emit(sw(30, 29, 0))
    c.send_uart(' S3=')
    c.bit_to_ascii(16, 1); c.emit(sw(30, 29, 0))
    c.send_uart(' S5=')
    c.bit_to_ascii(16, 2); c.emit(sw(30, 29, 0))
    for bit in range(4):
        c.send_uart(f' SW{bit+2}=')
        c.bit_to_ascii(17, bit); c.emit(sw(30, 29, 0))
    c.send_uart(' LED=')
    for bit in range(6):
        c.bit_to_ascii(12, bit); c.emit(sw(30, 29, 0))
    c.send_uart('\r\n')
    c.jump('sample')

    c.label('done')
    c.screen_text(24, 4, 'DONE: RETURN TO PiKoSoL; LED LATCHED AT LAST INPUT', FG_LIME)
    c.send_uart('[GPIO LIVE END: LED latched; RUN returning to PiKoSoL]\r\n')
    c.emit(ret())

    return c.finish()


def make(path):
    code = program()
    image = struct.pack('<IIII', MAGIC, 16 + len(code), ENTRY, 0) + code
    padded = ((len(image) + 127) // 128) * 128
    assert padded <= 0x3000, (len(image), padded)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(image)
    digest = hashlib.sha256(image).hexdigest()
    print(f'BIN BUILT (BOARD TEST REQUIRED): {path}')
    print(f'SIZE: {len(image)} bytes; XMODEM: {padded} bytes / {padded//128} blocks')
    print(f'SHA256: {digest}')
    return image


if __name__ == '__main__':
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', type=Path, default=Path(__file__).with_name('TP20_GPIO_KEYS_DIP_LED_TERMINAL_5S.bin'))
    args = ap.parse_args()
    make(args.out)
