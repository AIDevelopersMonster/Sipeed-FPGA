#!/usr/bin/env python3
"""Generate safe, freestanding PicoRV32 RV32I HDMI text demos for TP20.

No GCC required. Target: PiKoSoL TP20 app RAM 0x2000C000..0x2000FFFF,
entry 0x2000C010, video text 0x30000000, 96x42 cells.
Only writes 0x30000000..0x30003EFF, never GPIO, UART, Flash or DAC.
All generated binaries are NEW CANDIDATES; physical BOARD PASS not claimed.

To build using the actual operator-verified demo.bin magic:
 python build_apps.py --demo "C:/Users/.../firmware/demo.bin"
"""
from __future__ import annotations

import argparse
import hashlib
import math
from pathlib import Path
import struct
import sys

RAM_APP = 0x2000C000
ENTRY = RAM_APP + 16
VRAM = 0x30000000
COLS, ROWS = 96, 42
CAP = 0x3000  # PiKoSoL LOAD limit, including XMODEM pad
XBLOCK = 128
# Magic and four-word header established from board-tested demo.bin audit:
# first bytes 50 4B 44 31 ("PKD1") -> LE u32 0x31444B50.
# build_apps.py --demo PATH is the definitive operator-specific verifier.
SOURCE_MAGIC = 0x31444B50
DEMO_DIGEST = 'be20fb6ec6d1c7bfe1e9591f0c734649c61d200217f5ebf15800b4f4e681de26'

# THLN33 video_text.h color table: black, maroon, green, olive, navy,
# purple, teal, silver, gray, red, lime, yellow, blue, fuchsia, aqua, white.
BLACK, MAROON, GREEN, OLIVE, NAVY, PURPLE, TEAL, SILVER, GRAY, RED, LIME, YELLOW, BLUE, FUCHSIA, AQUA, WHITE = range(16)
NAMES = ('BLACK','MAROON','GREEN','OLIVE','NAVY','PURPLE','TEAL','SILVER',
         'GRAY','RED','LIME','YELLOW','BLUE','FUCHSIA','AQUA','WHITE')


def lui(rd, upper):
    assert 0 <= rd < 32 and 0 <= upper <= 0xfffff
    return ((upper & 0xfffff) << 12) | (rd << 7) | 0x37


def addi(rd, rs1, immediate):
    assert -2048 <= immediate <= 2047
    return ((immediate & 0xfff) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def sw(rs2, rs1, offset):
    assert -2048 <= offset <= 2047
    offset &= 0xfff
    return ((offset >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((offset & 31) << 7) | 0x23


def bne(rs1, rs2, offset):
    assert -4096 <= offset < 4096 and offset % 2 == 0
    u = offset & 0x1fff
    return (((u >> 12) & 1) << 31) | (((u >> 5) & 0x3f) << 25) | (rs2 << 20) | (rs1 << 15) | (1 << 12) | (((u >> 1) & 0xf) << 8) | (((u >> 11) & 1) << 7) | 0x63


def ret():
    return 0x00008067  # jalr x0,0(ra)


def split_address(a):
    hi = (a + 0x800) >> 12
    lo = a - (hi << 12)
    assert 0 <= hi < (1 << 20) and -2048 <= lo <= 2047
    return hi,lo


class Code:
    """Generate a small RV32I subset only, preserving x1/ra and x2/sp."""
    def __init__(self):
        self.ins = []
        self.labels = {}
        self.fix = []

    def emit(self, opcode):
        self.ins.append(opcode)

    def address(self, rd, address):
        hi, low = split_address(address)
        self.emit(lui(rd,hi))
        self.emit(addi(rd,rd,low))

    def label(self, name):
        assert name not in self.labels
        self.labels[name] = len(self.ins)

    def branch_neq(self, r1, r2, dest):
        self.fix.append((len(self.ins),r1,r2,dest))
        self.emit(0)

    def finish(self):
        for idx,r1,r2,name in self.fix:
            self.ins[idx] = bne(r1,r2,4 * (self.labels[name]-idx))
        assert self.ins[-1] == ret(), 'Must return to monitor'
        return struct.pack('<' + 'I'*len(self.ins),*self.ins)


class Screen:
    def __init__(self, name):
        self.name = name
        self.code = Code()
        self.clear(bg=NAVY)

    def clear(self,bg=NAVY):
        c=self.code
        c.address(5,VRAM)  # t0 video write pointer
        c.address(28,VRAM+COLS*ROWS*4) # t3 end exclusive
        c.emit(lui(6, (WHITE<<24 | bg<<16) >>12))
        c.emit(addi(6,6,32))
        c.label('clear_all')
        c.emit(sw(6,5,0))
        c.emit(addi(5,5,4))
        c.branch_neq(5,28,'clear_all')

    def text(self,x,y,text,fg=WHITE,bg=NAVY):
        assert 0 <= y < ROWS and 0 <= x < COLS
        try: data = text.encode('ascii')
        except UnicodeEncodeError as e: raise ValueError('ASCII only') from e
        if x + len(data)>COLS: raise ValueError(f'text out of bounds x={x}: {text}')
        if not data: return
        c=self.code
        c.address(5,VRAM+4*(y*COLS+x))
        c.emit(lui(6, (fg<<24 | bg<<16)>>12))
        for i,ch in enumerate(data):
            c.emit(addi(7,6,ch))
            c.emit(sw(7,5,i*4))

    def rectangle(self,x,y,width,height,bg,fg=WHITE):
        if x<0 or y<0 or x+width>COLS or y+height>ROWS or width<=0 or height<=0:
            raise ValueError('rect out of range')
        # Per-row loop: approximately 32 bytes of RV32I code per row,
        # instead of 8 bytes per filled character. Keeps all apps <16 KiB.
        c=self.code
        if not hasattr(self, '_rect_seq'): self._rect_seq=0
        for row in range(y,y+height):
            self._rect_seq+=1
            label=f'rect_{self._rect_seq}'
            start=VRAM+4*(row*COLS+x)
            c.address(5,start)
            c.address(28,start+width*4)
            c.emit(lui(6,(fg<<24|bg<<16)>>12))
            c.emit(addi(6,6,32))
            c.label(label)
            c.emit(sw(6,5,0))
            c.emit(addi(5,5,4))
            c.branch_neq(5,28,label)

    def bar(self,x,y,width,bg):
        self.rectangle(x,y,width,1,bg)

    def close(self):
        self.code.emit(ret())
        return self.code.finish()


def frame(title,subtitle,color=AQUA):
    s=Screen(title)
    s.rectangle(0,0,COLS,3,BLACK)
    s.text(3,1,'PiKoSoL TP20  /  '+title, YELLOW,BLACK)
    s.text(3,4,subtitle,WHITE,NAVY)
    s.bar(3,6,90,TEAL)
    s.bar(3,38,90,TEAL)
    s.text(4,39,'PicoRV32 / RV32I / HDMI 96x42   |   RAM ONLY   |   RET TO MONITOR',color,NAVY)
    s.text(4,40,'PC: pick .bin in File Manager  |  no FPGA Flash operations',SILVER,NAVY)
    return s


def app_hdmi_grid():
    s=frame('HDMI_GRID','MMIO VIDEO RAM 0x30000000 / CHARACTER AND COLOR TEST')
    s.text(6,9,'ABCDEFGH 0123456789  !@#$%^&*() []{} <> -+= /? ',WHITE,NAVY)
    s.text(6,11,'VIDEO GRID: 96 COLUMNS x 42 ROWS. FONT OUTPUT IS HARDWARE.',AQUA,NAVY)
    for y in (14,26,34):
        s.text(5,y,'+'+'-'*84+'+',YELLOW,NAVY)
    for y in range(15,26):
        s.text(5,y,'|',YELLOW,NAVY)
        s.text(90,y,'|',YELLOW,NAVY)
    for i,(name,col) in enumerate((('CYAN',AQUA),('GREEN',LIME),('YELLOW',YELLOW),('RED',RED),('MAGENTA',FUCHSIA))):
        s.text(9,16+i*2,f'{name:<8} COLOR TEST  '+('*'*(i+5)),col,NAVY)
    s.text(8,29,'Rows, colors and positioning: direct 32-bit video-cell stores.',WHITE,NAVY)
    s.text(8,31,'This program executes in APP RAM and RETURNS to PiKoSoL.',LIME,NAVY)
    return s.close()


def app_hdmi_palette():
    s=frame('HDMI_COLOR16','ALL 16 BUILT-IN COLOR INDEXES OF THE TEXT ENGINE')
    s.text(4,8,'FOREGROUND AND BACKGROUND COLOR PALETTE',WHITE,NAVY)
    for idx,name in enumerate(NAMES):
        col=idx%4; row=idx//4
        x=4+col*23; y=11+row*6
        s.rectangle(x,y,20,4,idx)
        fg=BLACK if idx in (7,8,10,11,14,15) else WHITE
        s.text(x+2,y+1,f'{idx:02} {name:<8}',fg,idx)
        s.text(x+2,y+2,'RGB via HDMI',fg,idx)
    s.text(4,36,'Note: these are HDMI text colors, NOT WS2812 LED control.',YELLOW,NAVY)
    return s.close()


def app_lcd_preview():
    s=frame('LCD_20x4_PREVIEW','20x4 CHARACTER LCD EMULATED ON HDMI (NO PHYSICAL LCD OUTPUT)')
    s.text(6,9,'External LCD controller: NOT PRESENT IN THIS FPGA BITSTREAM.',YELLOW,NAVY)
    s.rectangle(19,13,58,16,OLIVE)
    s.rectangle(22,15,52,12,BLACK)
    lines=['PIKOSOL 20X4 DISPLAY', 'CPU  RV32I  /  60MHz', 'VIDEO  96 X 42 CELLS', 'LCD BUS: NOT WIRED  ']
    assert all(len(x)<=20 for x in lines)
    for idx,line in enumerate(lines):
        s.text(29,17+idx*2,line.ljust(20),LIME,BLACK)
    s.text(7,31,'Implement real LCD: specify controller, PMOD pins and MMIO driver.',WHITE,NAVY)
    s.text(7,33,'This program only PREVIEWS the LCD interface through HDMI.',AQUA,NAVY)
    return s.close()


def app_rgb_preview():
    s=frame('RGB_WS2812_PREVIEW','COLOR TEST ON HDMI ONLY - NOT A PHYSICAL WS2812B DRIVER')
    s.text(4,9,'TP20 has a WS2812B, but this PicoRV32 build has no LED timing IP.',YELLOW,NAVY)
    for idx,(name,val,color) in enumerate((('RED',255,RED),('GREEN',170,LIME),('BLUE',85,BLUE))):
        yy=13+idx*7
        s.text(6,yy,name+' '+str(val).rjust(3)+' / 255',WHITE,NAVY)
        s.rectangle(26,yy-1,57,4,GRAY)
        s.rectangle(26,yy-1,int(val/255*57),4,color)
    s.text(7,36,'Physical WS2812: requires FPGA timing engine + safe PMOD pin mapping.',AQUA,NAVY)
    return s.close()


def app_audio_preview():
    s=frame('AUDIO_PT8211_PREVIEW','WAVEFORM VISUALIZATION ON HDMI - NO AUDIO OUTPUT')
    s.text(5,9,'PT8211 DAC / LPA4809: NOT CONNECTED IN CURRENT FPGA SOC.',YELLOW,NAVY)
    s.text(5,11,'Sound generation requires FPGA serial DAC timing + MMIO.',WHITE,NAVY)
    x0=7
    mid=23
    for xx in range(80):
        x=x0+xx
        y=mid+round(7*math.sin(xx*math.pi/13))
        s.text(x,y,'*',AQUA,NAVY)
        if xx%10==0: s.text(x,mid,'+',GRAY,NAVY)
    s.text(6,33,'This is a SILENT oscillator preview. No DAC pins are toggled.',LIME,NAVY)
    s.text(6,35,'Next hardware step: PT8211 LSB-justified serial controller.',AQUA,NAVY)
    return s.close()


APPS={
    'TP20_HDMI_GRID.bin':app_hdmi_grid,
    'TP20_HDMI_COLOR16.bin':app_hdmi_palette,
    'TP20_LCD_20X4_PREVIEW.bin':app_lcd_preview,
    'TP20_RGB_WS2812_PREVIEW.bin':app_rgb_preview,
    'TP20_AUDIO_PT8211_PREVIEW.bin':app_audio_preview,
}


def build_apps(output:Path,magic:int=SOURCE_MAGIC):
    output.mkdir(parents=True,exist_ok=True)
    items=[]
    for name,generate in APPS.items():
        code=generate()
        raw=struct.pack('<IIII',magic,16+len(code),ENTRY,0)+code
        padded=(len(raw)+XBLOCK-1)//XBLOCK*XBLOCK
        if padded>CAP: raise AssertionError(f'{name}: padded {padded}> {CAP}')
        path=output/name
        path.write_bytes(raw)
        items.append((path,raw))
    return items


def _sext(x,bits):
    return x-(1<<bits) if x&(1<<(bits-1)) else x


def emulate(raw,step_limit=50000):
    regs=[0]*32
    regs[1]=0xCAFEBABE  # supplied by PiKoSoL RUN caller
    code=raw[16:]
    pc=0
    mem={}
    step=0
    while 0<=pc<len(code):
        if step>=step_limit: raise AssertionError('STEP LIMIT')
        step+=1
        word,=struct.unpack_from('<I',code,pc)
        op=word&0x7f
        rd=(word>>7)&31
        rs1=(word>>15)&31
        rs2=(word>>20)&31
        nextpc=pc+4
        if op==0x37: regs[rd]=word&0xfffff000
        elif op==0x13:
            imm=_sext((word>>20)&0xfff,12)
            assert (word>>12)&7==0
            regs[rd]=(regs[rs1]+imm)&0xffffffff
        elif op==0x23:
            assert (word>>12)&7==2
            imm=_sext(((word>>25)<<5)|((word>>7)&31),12)
            addr=(regs[rs1]+imm)&0xffffffff
            if not (VRAM<=addr<VRAM+COLS*ROWS*4 and addr%4==0):
                raise AssertionError(f'UNSAFE WRITE: 0x{addr:08X}')
            mem[addr]=regs[rs2]
        elif op==0x63:
            assert (word>>12)&7==1
            imm=(((word>>31)&1)<<12)|(((word>>7)&1)<<11)|(((word>>25)&63)<<5)|(((word>>8)&15)<<1)
            if regs[rs1]!=regs[rs2]: nextpc=pc+_sext(imm,13)
        elif word==ret():
            assert regs[1]==0xCAFEBABE
            return mem,step
        else: raise AssertionError(f'UNHANDLED INSTRUCTION 0x{word:08X} pc={pc}')
        regs[0]=0
        pc=nextpc
    raise AssertionError('FALL THROUGH - no RET')


def test_apps(items,magic):
    for path,raw in items:
        assert raw==path.read_bytes()
        assert struct.unpack_from('<I',raw,0)[0]==magic
        assert struct.unpack_from('<I',raw,4)[0]==len(raw)
        assert struct.unpack_from('<I',raw,8)[0]==ENTRY
        assert struct.unpack_from('<I',raw,12)[0]==0
        mem,steps=emulate(raw)
        assert len(mem)>=COLS*ROWS, (path.name,len(mem))
        print(f'OFFLINE PASS {path.name:<30} {len(raw):5d} bytes, {steps:5d} instructions, '
              f'{len(mem):4d} video cells, SHA256={hashlib.sha256(raw).hexdigest()}')


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--demo',type=Path,help='path to the verified local firmware/demo.bin')
    ap.add_argument('--out',type=Path,default=Path(__file__).resolve().parent/'bin')
    ap.add_argument('--selftest',action='store_true')
    args=ap.parse_args()
    magic=SOURCE_MAGIC
    if args.demo:
        raw=args.demo.read_bytes()
        digest=hashlib.sha256(raw).hexdigest()
        if digest!=DEMO_DIGEST:
            ap.error('demo.bin SHA256 does not match the known board-tested image')
        magic,=struct.unpack_from('<I',raw)
        print(f'WORKING demo.bin verified, copying its magic word: 0x{magic:08X}')
    elif not args.selftest:
        print('NOTE: stock PiKoSoL demo.bin PKD1 signature used. Installer verifies the exact local demo SHA256 and regenerates before board upload.')
    items=build_apps(args.out,magic)
    test_apps(items,magic)
    with (args.out/'SHA256SUMS.txt').open('w',encoding='ascii') as out:
        for p,data in items:
            out.write(f'{hashlib.sha256(data).hexdigest()}  {p.name}\n')
    print('BUILD + OFFLINE TEST PASS; BOARD NOT YET TESTED; NO UART, FPGA OR FLASH ACCESS')


if __name__=='__main__':
    main()
