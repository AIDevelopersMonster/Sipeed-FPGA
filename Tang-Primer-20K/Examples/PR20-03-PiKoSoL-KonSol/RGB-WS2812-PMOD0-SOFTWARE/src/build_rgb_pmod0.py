#!/usr/bin/env python3
"""PiKoSoL TP20: software WS2812 through existing PMOD0[1] / T9.

No FPGA project change. Uses original MMIO 0x80000000, GPIO_ID, and existing
CLKREG. This is a first BOARD-UNVERIFIED waveform experiment, not a known
good WS2812 driver. The NOP timing must be confirmed on a real WS2812.
"""
from __future__ import annotations
import hashlib
import struct
from pathlib import Path
from rv32i_assembler import (Code, MAGIC, ENTRY, GPIO_ID_ADDR, GPIO_ID,
    UART_DATA, VRAM, WIDTH, addi, andi, lw, sw, rdcycle, sub, ret)

P0_OUT = 0x80000000
CLKREG = 0xE0000008   # Existing DCS CPU-clock selector; 2 = ~60 MHz
RGB_BIT = 2           # PMOD0[1] is T9; top board assigns pmod0 = ~out
NOP = 0x00000013     # addi x0,x0,0
BASE_HZ = 60_000_000
BIT_SLOTS = (4, 12, 10, 6)  # 0: HIGH nops, LOW nops; 1: HIGH nops, LOW nops
# Timing estimates only: PicoRV32 fetch+execution latency depends on BRAM/SoC.
# Each bit has exactly 16 NOPs and two word stores (18 RV32I instructions).
# Targets with ~4 cycles/NOP and ~5 cyc/store: T0H ~0.35us,
# T1H ~0.75us, bit slot ~1.23us @ 60 MHz. NOT MEASURED ON FPGA.
RESET_CYCLES = 12000  # ~200 us low @ 60MHz
HOLD_CYCLES = 60000000 # ~1s per frame at 60MHz
COLORS = [
    ("RED",   0x300000),
    ("GREEN", 0x003000),
    ("BLUE",  0x000030),
    ("OFF",   0x000000),
]


def grb_24(rgb):
    r=(rgb>>16)&255;g=(rgb>>8)&255;b=rgb&255
    return (g<<16)|(r<<8)|b


def generate():
    c=Code()
    # Preserve x1 (monitor return), x2, and all x8/x9,x18..x27.
    # x10=PMOD0_OUT; x11=CLKREG; x12=previous clock selection;
    # x13=PMOD0 GPIO register HIGH-on-wire; x14=LOW-on-wire;
    # x15=previous PMOD0 output (its seven other bits preserved).
    c.li(29, UART_DATA)
    c.li(6, GPIO_ID_ADDR)
    c.emit(lw(31, 6, 0))
    c.li(28, GPIO_ID)
    c.br('beq',31,28,'gpio_ok')
    c.uart('[RGB PMOD0: ABORT; no GP14 GPIO, no writes]\r\n')
    c.emit(ret())
    c.label('gpio_ok')
    c.li(10, P0_OUT)
    c.li(11, CLKREG)
    c.emit(lw(12,11,0),lw(15,10,0))
    c.emit(andi(13,15,-3)) # physical HIGH: GPIO OUT bit1=0, others unchanged
    # ORI x14,x15,2 guarantees output bit1=1 (physical WS2812 LOW)
    c.emit(((RGB_BIT & 0xfff)<<20)|(15<<15)|(6<<12)|(14<<7)|0x13)
    c.uart('[RGB via PMOD0[1]/T9, EXISTING FPGA, SW WS2812] START\r\n')
    c.text(1,3,'PiKoSoL RGB / EXISTING PMOD0[1] / PicoRV32',11)
    c.text(3,3,'FPGA T9 = PMOD0[1] = WS2812 DIN',15)
    c.text(7,3,'CURRENT: PENDING                        ',10)
    c.text(9,3,'NO NEW FPGA FS; GPIO_ID GP14 CHECKED',15)
    # Mandatory low reset/latch: bit1 of GPIO register =1 -> physical LOW.
    c.emit(sw(14,10,0))
    c.emit(addi(7,0,2),sw(7,11,0))  # existing CLKREG=2 (~60MHz)
    c.emit(rdcycle(16))
    c.li(17,120000)   # ~2ms PLL/DCS settle
    c.label('settle')
    c.emit(rdcycle(31),sub(31,31,16))
    c.br('bltu',31,17,'settle')
    for index,(name,rgb) in enumerate(COLORS):
        word=grb_24(rgb)
        c.text(7,12,f'{name:<8} RGB {rgb:06X}  GRB {word:06X}',10)
        c.emit(sw(14,10,0))
        c.emit(rdcycle(16))
        c.li(17,RESET_CYCLES)
        c.label(f'reset_wait_{index}')
        c.emit(rdcycle(31),sub(31,31,16))
        c.br('bltu',31,17,f'reset_wait_{index}')
        c.label(f'frame_{index}_start')
        for shift in range(23,-1,-1):
            bit=(word>>shift)&1
            hi_nops=BIT_SLOTS[2 if bit else 0]
            lo_nops=BIT_SLOTS[3 if bit else 1]
            c.emit(sw(13,10,0),*([NOP]*hi_nops))
            c.emit(sw(14,10,0),*([NOP]*lo_nops))
        c.label(f'frame_{index}_end')
        c.emit(rdcycle(16))
        c.li(17,HOLD_CYCLES)
        c.label(f'hold_{index}')
        c.emit(rdcycle(31),sub(31,31,16))
        c.br('bltu',31,17,f'hold_{index}')
    # Leave T9 LOW for WS2812 idle/latch (cannot restore old OUT[1]
    # if it was previously HIGH-on-wire, as it may break WS2812 reset).
    # Other seven PMOD0 bits are preserved by x14.
    c.emit(sw(14,10,0))
    c.emit(sw(12,11,0))  # restore previous CPU clock selection
    c.text(9,3,'DONE / RGB OFF / CLKREG RESTORED            ',10)
    c.uart('[RGB PMOD0: transmitted RED GREEN BLUE OFF; CLKREG restored]\r\n')
    c.uart('[RGB PMOD0: GPIO[1] left LOW (OUT bit1=1), all other P0 bits held]\r\n')
    c.emit(ret())
    body=c.finish()
    image=struct.pack('<IIII',MAGIC,16+len(body),ENTRY,0)+body
    assert struct.unpack_from('<IIII',image)==(MAGIC,len(image),ENTRY,0)
    blocks=(len(image)+127)//128
    if blocks*128>0x3000:
        raise ValueError(f'BIN does not fit 12 KiB XMODEM area: {len(image)} / {blocks} blocks')
    return image,c,blocks

if __name__=='__main__':
    p=Path(__file__).with_name('TP20_RGB_VIA_PMOD0_SOFTWARE_TEST.bin')
    data,c,blocks=generate()
    p.write_bytes(data)
    print(f'Created {p}, bytes={len(data)}, XMODEM={blocks} blocks, SHA256={hashlib.sha256(data).hexdigest().upper()}')
    print('BIN is a prototype; no physical WS2812 test has been performed.')
