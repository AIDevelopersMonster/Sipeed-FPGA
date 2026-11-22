#!/usr/bin/env python3
"""PiKoSoL TP20 V3714 PMOD2/PMOD3 LEDx8 walking-zero test.

Builds a PKD1 RV32I RAM application. No assembler, compiler, FPGA change or Flash.
Uses only the *existing, physically exercised* PiKoSoL GPIO V3714 register map.
16 one-at-a-time ACTIVE-LOW LEDs + UART logs + HDMI live readback.
Fail-closed GPIO ID check; PMOD2/3 OUT and DIR states restored before RET.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import struct

MAGIC=0x31444B50
ENTRY=0x2000C010
VRAM=0x30000000
UART_DATA=0x8000000C
P2_OUT=0x80000030
P2_IN=0x80000034
P2_DIR=0x80000038
P3_OUT=0x80000040
P3_IN=0x80000044
P3_DIR=0x80000048
GPIO_ID_ADDR=0x8000005C
GPIO_ID=0x47503134
WIDTH, HEIGHT=96,42
DELAY_CYCLES=12_000_000  # about 0.2s at TP20's nominal 60 MHz
FG_WHITE,FG_LIME,FG_YELLOW,FG_RED,BG_NAVY=15,10,11,9,4

def imm12(v):
    if not -2048<=v<=2047: raise ValueError(f'imm12 {v}')
    return v&0xfff

def lui(rd,v): return ((v&0xfffff)<<12)|(rd<<7)|0x37

def addi(rd,rs,v): return (imm12(v)<<20)|(rs<<15)|(rd<<7)|0x13

def andi(rd,rs,v): return (imm12(v)<<20)|(rs<<15)|(7<<12)|(rd<<7)|0x13

def slli(rd,rs,n): return (n<<20)|(rs<<15)|(1<<12)|(rd<<7)|0x13

def srli(rd,rs,n): return (n<<20)|(rs<<15)|(5<<12)|(rd<<7)|0x13

def sub(rd,a,b): return (0x20<<25)|(b<<20)|(a<<15)|(rd<<7)|0x33

def orr(rd,a,b): return (b<<20)|(a<<15)|(6<<12)|(rd<<7)|0x33

def lw(rd,base,off): return (imm12(off)<<20)|(base<<15)|(2<<12)|(rd<<7)|0x03

def sw(rs,base,off):
    v=imm12(off)
    return ((v>>5)<<25)|(rs<<20)|(base<<15)|(2<<12)|((v&31)<<7)|0x23

def branch(a,b,d,f3):
    if d%2 or not -4096<=d<4096: raise ValueError(f'branch offset {d}')
    v=d&0x1fff
    return (((v>>12)&1)<<31)|(((v>>5)&63)<<25)|(b<<20)|(a<<15)|(f3<<12)|(((v>>1)&15)<<8)|(((v>>11)&1)<<7)|0x63

def jump(d):
    if d%2 or not -(1<<20)<=d<(1<<20): raise ValueError(f'jal offset {d}')
    v=d&0x1fffff
    return (((v>>20)&1)<<31)|(((v>>1)&1023)<<21)|(((v>>11)&1)<<20)|(((v>>12)&255)<<12)|0x6f

def rdcycle(rd): return (0xc00<<20)|(2<<12)|(rd<<7)|0x73

def ret(): return 0x00008067

class Code:
    def __init__(self): self.w=[];self.labels={};self.fix=[]
    def emit(self,*x): self.w.extend(x)
    def label(self,s):
        if s in self.labels: raise ValueError(f'duplicate label {s}')
        self.labels[s]=len(self.w)
    def br(self,kind,a,b,label): self.fix.append((len(self.w),kind,a,b,label));self.emit(0)
    def j(self,label): self.br('j',0,0,label)
    def li(self,reg,value):
        value&=0xffffffff
        high=((value+0x800)>>12)&0xfffff
        low=(value-(high<<12))&0xffffffff
        if low>=0x80000000: low-=0x100000000
        self.emit(lui(reg,high),addi(reg,reg,low))
    def text(self,row,col,message,fg=FG_WHITE):
        if row>=HEIGHT or col+len(message)>WIDTH or not all(32<=ord(x)<127 for x in message):
            raise ValueError('invalid screen text')
        self.li(6,VRAM+4*(row*WIDTH+col))
        self.li(28,fg<<24|BG_NAVY<<16)
        for pos,ch in enumerate(message):
            self.emit(addi(30,28,ord(ch)),sw(30,6,4*pos))
    def uart(self,message):
        for ch in message:
            self.emit(addi(30,0,ord(ch)),sw(30,29,0))
    def hdmi_bits(self,row,col,src):
        self.li(6,VRAM+4*(row*WIDTH+col))
        self.li(28,FG_LIME<<24|BG_NAVY<<16)
        for n,bit in enumerate(range(7,-1,-1)):
            self.emit(srli(30,src,bit),andi(30,30,1),addi(30,30,48),orr(30,30,28),sw(30,6,4*n))
    def set_led_index(self):
        self.li(6,VRAM+4*(7*WIDTH+4+13)) # 'NOW PMOD2 BIT0' digit
        self.li(28,FG_YELLOW<<24|BG_NAVY<<16)
        self.emit(addi(30,16,48),orr(30,30,28),sw(30,6,0))
    def uart_step(self,p,ok):
        self.uart(f'P{p} BIT')
        self.emit(addi(30,16,48),sw(30,29,0))
        self.uart((' OK' if ok else ' MISMATCH')+'\r\n')
    def finish(self):
        for where,kind,a,b,target in self.fix:
            if target not in self.labels: raise ValueError(f'missing {target}')
            delta=(self.labels[target]-where)*4
            self.w[where]=jump(delta) if kind=='j' else branch(a,b,delta,{'beq':0,'bne':1,'bltu':6}[kind])
        if self.w[-1]!=ret(): raise ValueError('no ret')
        return struct.pack('<'+'I'*len(self.w),*self.w)

def make_program():
    c=Code()
    # Register contract: x1 (ra), x2 (sp) and all callee-saved regs untouched.
    # x10 pmod2 base; x11 pmod3 base; x12..15 saved OUT/DIR;
    # x5 mismatch count; x16 current index; x17 one-hot; x7 desired;
    # x29 UART; x6,x28,x30 display scratch; x31 readback/delay.
    c.li(10,P2_OUT); c.li(11,P3_OUT);c.li(29,UART_DATA)
    c.li(6,GPIO_ID_ADDR); c.emit(lw(31,6,0));c.li(28,GPIO_ID)
    c.br('beq',31,28,'id_ok')
    c.text(3,4,'PMOD TEST: GPIO_ID MISMATCH; NO PMOD WRITES',FG_RED)
    c.uart('\r\n[PMOD ERROR: GPIO_ID != GP14; no GPIO writes]\r\n')
    c.emit(ret())
    c.label('id_ok')
    # Save all four original PMOD2/3 registers; restore on exit.
    c.emit(lw(12,10,0),lw(13,10,8),lw(14,11,0),lw(15,11,8))
    c.emit(sw(0,10,8),sw(0,11,8))             # release pins before changing OUT
    c.emit(addi(7,0,255),sw(7,10,0),sw(7,11,0)) # OFF (active low)
    c.emit(sw(7,10,8),sw(7,11,8))               # drive all eight bits on each port
    # Clear rows 0..20; no changes to monitor RAM variables.
    c.li(6,VRAM); c.li(28,VRAM+21*WIDTH*4)
    c.li(30,FG_WHITE<<24|BG_NAVY<<16|ord(' '))
    c.label('screen_clear')
    c.emit(sw(30,6,0),addi(6,6,4));c.br('bne',6,28,'screen_clear')
    c.text(1,4,'PiKoSoL TP20  |  TWO PMOD-LEDx8  |  PicoRV32',FG_YELLOW)
    c.text(3,4,'PMOD2 OUT: 11111111     IN: 11111111')
    c.text(5,4,'PMOD3 OUT: 11111111     IN: 11111111')
    c.text(7,4,'NOW PMOD2 BIT0 (0=ON, 1=OFF)',FG_YELLOW)
    c.text(9,4,'Each GPIO pin LOW in turn.  All other pins HIGH.')
    c.text(11,4,'Input readback checks I/O LEVEL, not LED brightness.')
    c.text(13,4,'16 steps total. OUT/DIR restored at the end.')
    c.text(15,4,'No Flash. No FPGA reprogramming. Re-run with RUN.')
    c.text(17,4,'STATUS: RUNNING',FG_YELLOW)
    c.uart('\r\n[PiKoSoL TP20 PMOD2+3 LEDx8] 16 steps / active LOW / RESTORE\r\n')
    c.emit(addi(5,0,0),addi(16,0,0),addi(17,0,1))

    for number,base,row in ((2,10,3),(3,11,5)):
        c.label(f'phase{number}')
        c.emit(addi(7,0,255),sub(7,7,17),sw(7,base,0))
        c.emit(lw(31,base,4),andi(31,31,255))
        # Dynamic binary output level and readback, MSB-first.
        c.hdmi_bits(row,4+len(f'PMOD{number} OUT: '),7)
        c.hdmi_bits(row,4+len(f'PMOD{number} OUT: 11111111     IN: '),31)
        c.set_led_index()
        c.br('beq',7,31,f'pass{number}')
        c.emit(addi(5,5,1))
        c.uart_step(number,False)
        c.j(f'reported{number}')
        c.label(f'pass{number}')
        c.uart_step(number,True)
        c.label(f'reported{number}')
        # Wait a visible interval. rdcycle subtraction handles counter wraparound.
        c.emit(rdcycle(31))
        c.li(28,DELAY_CYCLES)
        c.label(f'wait{number}')
        c.emit(rdcycle(30),sub(30,30,31))
        # Need retain start register! sub makes elapsed, but x30 is disposable.
        c.br('bltu',30,28,f'wait{number}')
        c.emit(addi(16,16,1),slli(17,17,1),addi(7,0,8))
        c.br('bne',16,7,f'phase{number}')
        # Transition to second module: all PMOD2 LEDs OFF before PMOD3 test.
        if number==2:
            c.emit(addi(7,0,255),sw(7,10,0),addi(16,0,0),addi(17,0,1))
            c.text(7,4,'NOW PMOD3 BIT0 (0=ON, 1=OFF)',FG_YELLOW)

    # Turn both banks OFF, then restore the precise previous OUT/DIR state.
    c.emit(addi(7,0,255),sw(7,10,0),sw(7,11,0))
    c.emit(sw(0,10,8),sw(0,11,8))
    c.emit(sw(12,10,0),sw(14,11,0),sw(13,10,8),sw(15,11,8))
    c.br('beq',5,0,'all_good')
    c.text(17,4,'DONE: INPUT READBACK MISMATCH - CHECK UART',FG_RED)
    c.uart('[PMOD END: READBACK MISMATCH; previous OUT/DIR restored]\r\n')
    c.j('end')
    c.label('all_good')
    c.text(17,4,'DONE: 16/16 DIGITAL READBACK PASS',FG_LIME)
    c.uart('[PMOD END: DIGITAL READBACK PASS 16/16; OUT/DIR restored]\r\n')
    c.label('end')
    c.emit(ret())
    return c.finish()

def build(path:Path):
    body=make_program()
    image=struct.pack('<IIII',MAGIC,16+len(body),ENTRY,0)+body
    padded=(len(image)+127)//128*128
    if padded>0x3000: raise ValueError(f'BIN too large: {len(image)} bytes, padded {padded}>12KiB')
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(image)
    print('FILE',path)
    print('SIZE',len(image),'XMODEM_BLOCKS',padded//128)
    print('SHA256',hashlib.sha256(image).hexdigest().upper())
    return image

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,default=Path(__file__).with_name('TP20_PMOD2_PMOD3_LED16_CHASE.bin'))
    args=parser.parse_args()
    build(args.out)
