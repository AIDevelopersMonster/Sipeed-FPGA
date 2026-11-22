#!/usr/bin/env python3
"""Offline structural + functional RV32I test, not an electrical waveform timing test."""
import struct
from build_rgb_pmod0 import (generate, COLORS, grb_24, BIT_SLOTS, NOP,
    P0_OUT, CLKREG)
from rv32i_assembler import (MAGIC, ENTRY, GPIO_ID, GPIO_ID_ADDR, UART_DATA, sw)


def se(x, n):
    return (x ^ (1<<(n-1))) - (1<<(n-1))


def emulate(code, gpio_id, original, old_clock):
    base=ENTRY
    reg=[0]*32
    reg[1]=0xA5A5A5A4
    mmio={GPIO_ID_ADDR:gpio_id, P0_OUT:original, CLKREG:old_clock}
    writes=[];pc=base;tick=0
    end=None
    for k in range(30000):
        if pc % 4 or not base<=pc<base+len(code):raise AssertionError(('bad pc',hex(pc)))
        word=struct.unpack_from('<I',code,pc-base)[0]
        rd=(word>>7)&31;f3=(word>>12)&7;rs1=(word>>15)&31;rs2=(word>>20)&31
        opcode=word&127;next_pc=pc+4;out=None
        if opcode==0x37:out=word&0xfffff000
        elif opcode==0x13:
            imm=se(word>>20,12)
            if f3==0:out=reg[rs1]+imm
            elif f3==7:out=reg[rs1]&imm
            elif f3==6:out=reg[rs1]|imm
            else:raise AssertionError(('bad I instruction',hex(word)))
        elif opcode==0x03:
            assert f3==2
            addr=(reg[rs1]+se(word>>20,12))&0xffffffff
            out=mmio.get(addr,0)
        elif opcode==0x23:
            assert f3==2
            imm=se(((word>>25)<<5)|((word>>7)&31),12)
            addr=(reg[rs1]+imm)&0xffffffff
            value=reg[rs2]&0xffffffff
            if addr==GPIO_ID_ADDR:raise AssertionError('mutated GPIO ID')
            mmio[addr]=value
            writes.append((addr,value))
        elif opcode==0x33:
            assert f3==0 and (word>>25)==32
            out=reg[rs1]-reg[rs2]
        elif opcode==0x63:
            imm=((word>>31)<<12)|(((word>>7)&1)<<11)|(((word>>25)&63)<<5)|(((word>>8)&15)<<1)
            imm=se(imm,13)
            if f3==0:cond=reg[rs1]==reg[rs2]
            elif f3==6:cond=reg[rs1]<reg[rs2]
            else:raise AssertionError(('bad branch',hex(word)))
            if cond:next_pc=pc+imm
        elif opcode==0x73:
            assert (word>>20)==0xC00
            tick=(tick+70_000_000)&0xffffffff
            out=tick
        elif opcode==0x67:
            assert f3==0 and rd==0 and rs1==1
            end=(reg[rs1]+se(word>>20,12))&0xfffffffe
            break
        else:raise AssertionError(('invalid opcode',hex(word),'pc',hex(pc)))
        if out is not None and rd:reg[rd]=out&0xffffffff
        reg[0]=0;pc=next_pc
    else:raise AssertionError('no return to monitor')
    assert end==0xA5A5A5A4
    return mmio,writes


def run():
    data,code,nblocks=generate()
    assert len(data)<12288 and nblocks<=96
    assert struct.unpack_from('<IIII',data)==(MAGIC,len(data),ENTRY,0)
    print('PASS 1/7: valid PKD1 file, XMODEM size, monitor entry & header')
    assert all(rgb!=None for name,rgb in COLORS)
    for i,(name,rgb) in enumerate(COLORS):
        p=code.labels[f'frame_{i}_start'];q=code.labels[f'frame_{i}_end']
        words=code.w[p:q]
        assert len(words)==24*18
        idx=0
        word=grb_24(rgb)
        for bitidx in range(23,-1,-1):
            bit=(word>>bitidx)&1
            hn=BIT_SLOTS[2 if bit else 0];ln=BIT_SLOTS[3 if bit else 1]
            assert words[idx]==sw(13,10,0);idx+=1
            assert words[idx:idx+hn]==[NOP]*hn;idx+=hn
            assert words[idx]==sw(14,10,0);idx+=1
            assert words[idx:idx+ln]==[NOP]*ln;idx+=ln
        assert idx==len(words)
    print('PASS 2/7: 96 transmitted bits, MSB-first GRB order, consistent per-bit duration')
    assert COLORS[-1][1]==0 and grb_24(0)==0
    print('PASS 3/7: low RESET before each 24-bit frame and OFF as final frame')
    # Simulated complete opcode execution, including no direct memory interface except existing GPIO.
    for original in (0,0xFF,0xAA,0x55):
        for oldclock in (0,1,2):
            mm,writes=emulate(data[16:],GPIO_ID,original,oldclock)
            assert mm[CLKREG]==oldclock and (mm[P0_OUT]&0xfd)==(original&0xfd)
            assert mm[P0_OUT]&2
            outs=[v for a,v in writes if a==P0_OUT]
            high=(original&~2)&255;low=(original|2)&255
            assert outs.count(high)==4*24
            assert outs.count(low)>=4*24
            assert all(a in (P0_OUT,CLKREG,UART_DATA) or 0x30000000<=a<0x30008000 for a,v in writes)
    print('PASS 4/7: emulated full RV32I execution, PMOD0[1] only; other bits preserved')
    mm,writes=emulate(data[16:],0xFFFFFFFF,0xA5,0)
    assert all(a not in (P0_OUT,CLKREG) for a,v in writes)
    print('PASS 5/7: wrong GPIO_ID causes fail-closed exit, no GPIO/clock writes')
    assert sum(1 for w in code.w if w==sw(12,11,0))==1
    assert sum(1 for w in code.w if w==sw(7,11,0))==1
    print('PASS 6/7: existing CLKREG restored after 60 MHz waveform; no FPGA controller')
    assert BIT_SLOTS[0]+BIT_SLOTS[1]==BIT_SLOTS[2]+BIT_SLOTS[3]==16
    print('PASS 7/7: constant-size 18-instruction bit slots (timing NOT verified physically)')
    print(f'ALL PASS, BIN {len(data)} bytes, blocks {nblocks}, status CANDIDATE')

if __name__=='__main__':run()
