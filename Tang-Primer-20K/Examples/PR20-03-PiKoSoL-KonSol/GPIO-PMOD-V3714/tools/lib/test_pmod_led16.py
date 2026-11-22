#!/usr/bin/env python3
"""Offline instruction-by-instruction RV32I verification of PMOD2/3 RAM test.
This checks machine-code paths, register preservation, I/O writes and restore.
It is NOT physical BOARD PASS.
"""
import struct
import unittest
from pathlib import Path
from build_pmod_led16 import (build,GPIO_ID,GPIO_ID_ADDR,ENTRY,UART_DATA,VRAM,
    P2_OUT,P2_IN,P2_DIR,P3_OUT,P3_IN,P3_DIR,WIDTH,HEIGHT)

MASK=0xffffffff

def sext(v,n): return v-(1<<n) if v&(1<<(n-1)) else v

class Sim:
    def __init__(self,data,id=GPIO_ID,mismatch=False,initial=None):
        self.data=data[16:];self.id=id;self.mismatch=mismatch
        self.mem={P2_OUT:0xaa,P2_DIR:0,P3_OUT:0x55,P3_DIR:0xf0} if initial is None else dict(initial)
        self.initial=dict(self.mem);self.reg=[0]*32
        for rd in (1,2,8,9,*range(18,28)):
            self.reg[rd]=(0xcafebabe + rd)&MASK
        self.preserved={n:self.reg[n] for n in (1,2,8,9,*range(18,28))}
        self.pc=0;self.cycle=0;self.cpi=400000;self.steps=0
        self.writes=[];self.video={};self.uart=bytearray();self.stopped=False
    def rd(self,a):
        if a==GPIO_ID_ADDR:return self.id
        if a in (P2_OUT,P2_DIR,P3_OUT,P3_DIR):return self.mem[a]
        if a in (P2_IN,P3_IN):
            base=P2_OUT if a==P2_IN else P3_OUT
            raw=(self.mem[base] | (~self.mem[base+8] & 0xff)) & 255
            if self.mismatch and base==P3_OUT and raw!=255:return raw^1
            return raw
        raise AssertionError(f'INVALID MMIO READ {a:08x}')
    def wr(self,a,v):
        if a in (P2_OUT,P2_DIR,P3_OUT,P3_DIR):
            if v&~255:raise AssertionError(f'BAD PAD VALUE {v:x}')
            self.mem[a]=v;self.writes.append((a,v))
        elif a==UART_DATA:
            if v&~255: raise AssertionError('BAD UART CHAR')
            self.uart.append(v)
        elif VRAM<=a<VRAM+WIDTH*HEIGHT*4 and a%4==0:
            self.video[a]=v
        else:raise AssertionError(f'UNSAFE STORE {a:08x}: {v:08x}')
    def run(self,maxsteps=100000):
        while 0<=self.pc<len(self.data):
            self.steps+=1;self.cycle=(self.cycle+self.cpi)&MASK
            if self.steps>maxsteps:raise AssertionError('STEP LIMIT')
            ins,=struct.unpack_from('<I',self.data,self.pc)
            op=ins&127;rd=(ins>>7)&31;f3=(ins>>12)&7;rs=(ins>>15)&31;rb=(ins>>20)&31
            dst=self.pc+4
            if ins==0x00008067:
                for k,v in self.preserved.items():
                    if self.reg[k]!=v:raise AssertionError(f'PRESERVED x{k} CLOBBERED')
                self.stopped=True;return self
            if op==0x37: self.reg[rd]=ins&0xfffff000
            elif op==0x13:
                im=sext(ins>>20,12)
                if f3==0: self.reg[rd]=(self.reg[rs]+im)&MASK
                elif f3==7: self.reg[rd]=self.reg[rs]&im&MASK
                elif f3==1: self.reg[rd]=(self.reg[rs]<<(rb&31))&MASK
                elif f3==5: self.reg[rd]=self.reg[rs]>>(rb&31)
                else:raise AssertionError('unsupported opimm')
            elif op==0x33:
                if f3==0 and ins>>25==0x20:
                    self.reg[rd]=(self.reg[rs]-self.reg[rb])&MASK
                elif f3==6 and ins>>25==0:
                    self.reg[rd]=self.reg[rs]|self.reg[rb]
                else:raise AssertionError('unsupported op')
            elif op==0x03:
                if f3!=2:raise AssertionError('BAD LW')
                addr=(self.reg[rs]+sext(ins>>20,12))&MASK
                self.reg[rd]=self.rd(addr)
            elif op==0x23:
                if f3!=2:raise AssertionError('BAD SW')
                im=sext(((ins>>25)<<5)|((ins>>7)&31),12)
                addr=(self.reg[rs]+im)&MASK
                self.wr(addr,self.reg[rb])
            elif op==0x63:
                im=sext((((ins>>31)&1)<<12)|(((ins>>7)&1)<<11)|(((ins>>25)&63)<<5)|(((ins>>8)&15)<<1),13)
                a,b=self.reg[rs],self.reg[rb]
                take={0:a==b,1:a!=b,6:a<b}.get(f3)
                if take is None:raise AssertionError('unsupported branch')
                if take:dst=self.pc+im
            elif op==0x6f:
                if rd!=0:raise AssertionError('unexpected jal rd')
                im=sext((((ins>>31)&1)<<20)|(((ins>>12)&255)<<12)|(((ins>>20)&1)<<11)|(((ins>>21)&1023)<<1),21)
                dst=self.pc+im
            elif op==0x73:
                if f3!=2 or ins>>20!=0xc00 or rs!=0:raise AssertionError('bad csr')
                self.reg[rd]=self.cycle
            else:raise AssertionError(f'unsupported machine instruction at {self.pc:x}: {ins:08x}')
            self.reg[0]=0
            self.pc=dst
        raise AssertionError('fell through')
    def txt(self,row,col,length):
        return ''.join(chr(self.video.get(VRAM+(row*WIDTH+col+i)*4,0)&255) for i in range(length))

class PmodTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw=build(Path(__file__).with_name('TP20_PMOD2_PMOD3_LED16_CHASE.bin'))
    def test_header_and_xmodem_limit(self):
        self.assertEqual(struct.unpack_from('<IIII',self.raw),(0x31444b50,len(self.raw),ENTRY,0))
        self.assertLessEqual((len(self.raw)+127)//128*128,0x3000)
    def test_full_loop_uart_hdmi_and_register_restore(self):
        s=Sim(self.raw).run()
        self.assertTrue(s.stopped)
        self.assertEqual(s.mem,s.initial)
        expected=[255^(1<<i) for i in range(8)]
        for port in [P2_OUT,P3_OUT]:
            actual=[v for a,v in s.writes if a==port and v!=255 and v!=s.initial[port]]
            self.assertEqual(actual,expected,(hex(port),actual))
        msg=s.uart.decode('ascii')
        for port in (2,3):
            for i in range(8):
                self.assertIn(f'P{port} BIT{i} OK',msg)
        self.assertIn('READBACK PASS 16/16',msg)
        self.assertIn('PMOD2 OUT:',s.txt(3,4,12))
        self.assertIn('PMOD3 OUT:',s.txt(5,4,12))
        self.assertIn('DONE: 16/16 DIGITAL',s.txt(17,4,45))
        print('OK:',s.steps,'rv32i instructions,',len(s.writes),'PMOD register writes')
    def test_gpio_id_fail_closed(self):
        s=Sim(self.raw,id=0).run()
        self.assertEqual(s.writes,[])
        self.assertEqual(s.mem,s.initial)
        self.assertIn('no GPIO writes',s.uart.decode('ascii'))
    def test_physical_readback_fault_detected_and_restored(self):
        s=Sim(self.raw,mismatch=True).run()
        self.assertEqual(s.mem,s.initial)
        self.assertIn('MISMATCH',s.uart.decode('ascii'))
        self.assertIn('READBACK MISMATCH',s.uart.decode('ascii'))
        self.assertIn('DONE: INPUT READBACK MISMATCH',s.txt(17,4,48))
    def test_repeat_run_state_independent(self):
        s1=Sim(self.raw).run()
        s2=Sim(self.raw,initial=s1.mem).run()
        self.assertEqual(s1.uart,s2.uart)
        self.assertEqual(s2.mem,s2.initial)

if __name__=='__main__': unittest.main(verbosity=2)
