#!/usr/bin/env python3
"""Behavioral RV32I subset smoke test, not an RTL/FPGA verification."""
from pathlib import Path
from assemble import parse_lines, assemble_instruction, REG

MASK=0xFFFFFFFF

def sext(x, bits):
    x &= (1<<bits)-1
    return x if (x >> (bits-1)) == 0 else x-(1<<bits)

def run(image, steps=2000):
    code=[int(x,16) for x in image.read_text(encoding='ascii').splitlines()]
    regs=[0]*32; pc=0; cycles=0; leds=0; test_status=0; serial=[]
    for _ in range(steps):
        assert pc%4==0 and 0<=pc//4<len(code), f'PC outside ROM: {pc:#x}'
        ins=code[pc//4]; cycles+=1
        op=ins&127; rd=(ins>>7)&31; f3=(ins>>12)&7; s1=(ins>>15)&31; s2=(ins>>20)&31
        n=pc+4
        if op==0x37: regs[rd]=ins&0xFFFFF000
        elif op==0x13:
            if f3==0: regs[rd]=(regs[s1]+sext(ins>>20,12))&MASK
            elif f3==7: regs[rd]=regs[s1]&(ins>>20)
            elif f3==5: regs[rd]=(regs[s1]>>((ins>>20)&31))&MASK
            else: raise AssertionError('bad I-type')
        elif op==0x03:
            assert f3==2
            addr=(regs[s1]+sext(ins>>20,12))&MASK
            if addr==0x20000000: val=leds
            elif addr==0x20000004: val=cycles
            elif addr==0x20000008: val=0x5A5A0001
            elif addr==0x2000000C: val=test_status
            elif addr==0x20000014: val=1  # abstract always-ready transmitter
            else: raise AssertionError(f'unmapped LW at {addr:#x}')
            regs[rd]=val
        elif op==0x23:
            assert f3==2
            im=((ins>>25)<<5)|((ins>>7)&31)
            addr=(regs[s1]+sext(im,12))&MASK
            value=regs[s2]
            if addr==0x20000000: leds=value&63
            elif addr==0x2000000C: test_status=value
            elif addr==0x20000010: serial.append(value&255)
            else: raise AssertionError(f'unmapped SW at {addr:#x}')
        elif op==0x63:
            b=(((ins>>31)&1)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&63)<<5)|(((ins>>8)&15)<<1)
            if (f3==0 and regs[s1]==regs[s2]) or (f3==1 and regs[s1]!=regs[s2]): n=pc+sext(b,13)
        elif op==0x6F:
            j=(((ins>>31)&1)<<20)|(((ins>>12)&255)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&1023)<<1)
            regs[rd]=n; n=pc+sext(j,21)
        elif op==0x67:
            assert f3==0
            target=(regs[s1]+sext(ins>>20,12))&~1
            regs[rd]=n; n=target
        else: raise AssertionError(f'bad opcode 0x{op:02x} at {pc:#x}')
        regs[0]=0; pc=n
        if test_status==0x600DCAFE:
            assert bytes(serial)==b'PICO\n', f'bad UART content: {bytes(serial)!r}'
            print(f'FIRMWARE MODEL PASS: UART={bytes(serial)!r}; steps={cycles}; STATUS={test_status:08x}; LED={leds:02x}')
            return
    raise AssertionError(f'timeout at pc={pc:#x}, UART={bytes(serial)!r}, status={test_status:08x}')

if __name__=='__main__':
    base=Path(__file__).resolve().parents[1]
    source, labels=parse_lines(base/'firmware'/'boot.S')
    in_rom=[int(x,16) for x in (base/'firmware'/'boot.hex').read_text().splitlines()]
    check=[assemble_instruction(op,i*4,labels) for i,(_,op) in enumerate(source)]
    assert in_rom[:len(check)]==check
    run(base/'firmware'/'boot.hex')
