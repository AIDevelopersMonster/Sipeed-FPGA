#!/usr/bin/env python3
"""TP20 GPIO (PMOD0) active-high-register LEDx8 slow visual diagnostic.

For board-tested PiKoSoL V3714 GP14 bitstream only. The original RTL drives
pmod0 pins as ~port_out. Sipeed PMOD-LEDx8 is physically active low, hence
port_out bit=1 should LIGHT the corresponding PMOD0 LED.

No FPGA programming. Writes legacy PMOD0_OUT (0x80000000) and UART/HDMI only.
PMOD0 has no DIR register. All other PMOD1-3 and onboard LEDs untouched.
"""
from __future__ import annotations
import hashlib
import struct
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'lib'))
from build_pmod_led16 import (Code,MAGIC,ENTRY,VRAM,WIDTH,HEIGHT,GPIO_ID,GPIO_ID_ADDR,UART_DATA,
    lw,sw,addi,andi,sub,ret,rdcycle,srli,slli,orr)

P0_OUT=0x80000000
P0_IN =0x80000004
# Total approximately 5.4 seconds with a nominal 60 MHz CPU clock.
HOLD_LONG = 30_000_000  # 0.50 s for the four full-width patterns
HOLD_WALK = 24_000_000  # 0.40 s for each of eight moving-bit states


def build_code() -> bytes:
    c=Code()
    # x1, x2, x8, x9, x18-x27 are not used, preserving monitor ABI.
    # x10 PMOD0 base, x29 UART, x15 previous OUT, x5 mismatch counter;
    # x7 OUT mask, x12 physical IN, x13 expected ~OUT;
    # x6,x28,x30 screen/printing scratch, x16 and x17 for timer.
    c.li(10,P0_OUT); c.li(29,UART_DATA)
    c.li(6,GPIO_ID_ADDR); c.emit(lw(31,6,0)); c.li(28,GPIO_ID)
    c.br('beq',31,28,'id_ok')
    c.text(3,3,'PMOD0 STOP: GPIO_ID != GP14, NO WRITES',9)
    c.uart('\r\n[PMOD0 STOP: wrong GPIO_ID, no GPIO writes]\r\n')
    c.emit(ret())
    c.label('id_ok')
    c.emit(lw(15,10,0))
    c.emit(addi(5,0,0))  # mismatch counter

    # Clear top 19 HDMI rows so stale monitor text cannot obscure test.
    c.li(6,VRAM); c.li(28,VRAM+19*WIDTH*4)
    c.li(30,(15<<24)|(4<<16)|32)
    c.label('clear')
    c.emit(sw(30,6,0),addi(6,6,4))
    c.br('bne',6,28,'clear')

    c.text(1,4,'PiKoSoL PMOD0 GPIO LEDx8',11)
    c.text(3,4,'PMOD0 OUT: 00000000   PIN IN: 11111111')
    c.text(5,4,'OUT 1 = LED ON',11)
    c.text(7,4,'OFF / ON / 55 / AA / WALK0..7')
    c.text(9,4,'STEP 00/12',11)
    c.text(11,4,'LATCH; RUN FLIPS 55/AA')
    c.text(13,4,'PIN IN: DIGITAL ONLY')
    c.text(15,4,'RAM ONLY / NO FLASH')
    c.text(17,4,'RESULT: WAIT')
    c.uart('\r\n[PiKoSoL PMOD0 GPIO LEDx8]\r\n')

    bit_display_count=0
    def bitdisplay(row,col,src):
        """Compact dynamic 8-bit MSB-first HDMI writer (no unrolling)."""
        nonlocal bit_display_count
        bit_display_count+=1
        label=f'bits_{bit_display_count}'
        c.li(6,VRAM+4*(row*WIDTH+col))
        c.li(28,(10<<24)|(4<<16))  # foreground lime, background navy
        c.emit(addi(14,src,0))     # copy, retain OUT and IN for comparison
        c.emit(addi(31,0,8))
        c.label(label)
        c.emit(srli(30,14,7),andi(30,30,1),addi(30,30,48),orr(30,30,28),sw(30,6,0))
        c.emit(addi(6,6,4),slli(14,14,1),addi(31,31,-1))
        c.br('bne',31,0,label)

    def refresh(step,mask,label,duration):
        # Data -> external pins: pmod0 = ~ OUT. LED module: physical zero = ON.
        c.emit(addi(7,0,mask), sw(7,10,0))
        c.uart(f'P0 {step:02d}/12 {label} {mask:02X}\r\n')
        # UART transfer gives the physical pin readback time to settle.
        c.emit(lw(12,10,4),andi(12,12,255))
        c.emit(addi(13,0,255),sub(13,13,7))
        c.br('beq',12,13,f'match_{step}')
        c.emit(addi(5,5,1))
        c.label(f'match_{step}')
        bitdisplay(3,4+len('PMOD0 OUT: '),7)
        bitdisplay(3,4+len('PMOD0 OUT: 00000000   PIN IN: '),12)
        c.text(9,9,f'{step:02d}')
        # Physical pin input level is shown live as eight bits on HDMI.
        c.emit(rdcycle(16)); c.li(17,duration)
        c.label(f'hold_{step}')
        c.emit(rdcycle(30),sub(30,30,16))
        c.br('bltu',30,17,f'hold_{step}')

    phases=[(0x00,'ALL_OFF',HOLD_LONG),
            (0xFF,'ALL_ON ',HOLD_LONG),
            (0x55,'ALT_55 ',HOLD_LONG),
            (0xAA,'ALT_AA ',HOLD_LONG)]
    phases.extend(((1<<bit),f'BIT{bit}   ',HOLD_WALK) for bit in range(8))
    for n,(mask,label,duration) in enumerate(phases,1): refresh(n,mask,label,duration)

    # Initial prior OUT=0x55 -> final 0xAA; otherwise -> 0x55.
    c.emit(addi(7,0,0x55))
    c.br('bne',15,7,'latch_55')
    c.emit(addi(7,0,0xAA));c.j('latch_now')
    c.label('latch_55');c.emit(addi(7,0,0x55))
    c.label('latch_now');c.emit(sw(7,10,0))
    c.uart('[PMOD0 FINAL ALTERNATE LATCH]\r\n')
    c.emit(lw(12,10,4),andi(12,12,255))
    c.emit(addi(13,0,255),sub(13,13,7))
    c.br('beq',12,13,'final_read_ok')
    c.emit(addi(5,5,1))
    c.label('final_read_ok')
    bitdisplay(3,4+len('PMOD0 OUT: '),7)
    bitdisplay(3,4+len('PMOD0 OUT: 00000000   PIN IN: '),12)
    c.br('beq',5,0,'all_ok')
    # Electrical level readback mismatch: take PMOD0 back to all LED OFF.
    c.emit(sw(0,10,0))
    c.text(17,4,'RESULT: READBACK MISMATCH / PORT0 SET TO OFF',9)
    c.uart('[PMOD0 READBACK MISMATCH; OUT RESET TO 00]\r\n')
    c.j('finish')
    c.label('all_ok')
    c.text(17,4,'RESULT: DIGITAL READBACK OK; VERIFY REAL LEDS',10)
    c.uart('[PMOD0 DIGITAL READBACK OK / CHECK REAL LEDS]\r\n')
    c.label('finish'); c.emit(ret())
    return c.finish()


def build(out_dir:Path) -> tuple[Path,bytes]:
    out_dir.mkdir(parents=True,exist_ok=True)
    body=build_code()
    data=struct.pack('<IIII',MAGIC,16+len(body),ENTRY,0)+body
    nblocks=(len(data)+127)//128
    if nblocks*128>0x3000:raise ValueError(f'BIN too large {len(data)} > 12KiB XMODEM')
    assert struct.unpack_from('<IIII',data)==(MAGIC,len(data),ENTRY,0)
    p=out_dir/'TP20_PMOD0_GPIO_SLOW_VISUAL_LATCH.bin'
    p.write_bytes(data)
    print(f'BUILT: {p.name} SIZE={len(data)} BLOCKS={nblocks} SHA256={hashlib.sha256(data).hexdigest().upper()}')
    return p,data


def build_off(out_dir:Path) -> tuple[Path,bytes]:
    """Safe OFF image for the original PMOD0 output (no tri-state available)."""
    c=Code()
    c.li(29,UART_DATA)
    c.li(6,GPIO_ID_ADDR);c.emit(lw(31,6,0));c.li(28,GPIO_ID)
    c.br('beq',31,28,'id_ok')
    c.uart('[PMOD0 OFF STOP: wrong GPIO_ID, no write]\r\n')
    c.emit(ret())
    c.label('id_ok')
    c.li(10,P0_OUT)
    c.emit(sw(0,10,0))
    c.uart('[PMOD0 GPIO OFF: OUT=00, physical HIGH]\r\n')
    c.emit(ret())
    code=c.finish()
    data=struct.pack('<IIII',MAGIC,16+len(code),ENTRY,0)+code
    assert (len(data)+127)//128*128<=0x3000
    p=out_dir/'TP20_PMOD0_GPIO_ALL_OFF.bin'
    p.write_bytes(data)
    print(f'BUILT: {p.name} SIZE={len(data)} SHA256={hashlib.sha256(data).hexdigest().upper()}')
    return p,data

if __name__=='__main__':
    build(Path(__file__).resolve().parent)
    build_off(Path(__file__).resolve().parent)
