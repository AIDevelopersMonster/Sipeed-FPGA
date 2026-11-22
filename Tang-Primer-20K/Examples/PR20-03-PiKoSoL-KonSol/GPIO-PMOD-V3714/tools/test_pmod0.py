#!/usr/bin/env python3
"""Host-only RV32I instruction-by-instruction verification for legacy PMOD0.

These are model tests, not a physical BOARD PASS.
"""
from __future__ import annotations
import struct
import unittest
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent/'lib'))
from build_pmod_led16 import GPIO_ID, VRAM, WIDTH, HEIGHT, UART_DATA
from test_pmod_led16 import Sim
from build_pmod0 import build,build_off,P0_OUT,P0_IN

class Pmod0Sim(Sim):
    def __init__(self, data, id=GPIO_ID, mismatch=False, initial=None):
        if initial is None:
            initial={P0_OUT:0,0x80000020:0x55,0x80000028:0,
                     0x80000030:0xaa,0x80000038:0,0x80000040:0xf0,0x80000048:0}
        super().__init__(data,id=id,mismatch=mismatch,initial=initial)
        self.cpi=1_000_000
    def rd(self,a):
        if a==P0_OUT: return self.mem[P0_OUT]
        if a==P0_IN:
            value=(self.mem[P0_OUT]^0xff)&255
            return (value ^ 1) if self.mismatch else value
        return super().rd(a)
    def wr(self,a,v):
        if a==P0_OUT:
            assert v&~0xff==0,('bad PMOD0 write',v)
            self.mem[a]=v
            self.writes.append((a,v))
        elif a==UART_DATA or VRAM<=a<VRAM+WIDTH*HEIGHT*4:
            super().wr(a,v)
        else:
            raise AssertionError(f'UNSAFE NON-PMOD0 MMIO WRITE: {a:08X} = {v:08X}')

class Pmod0Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.path,cls.img=build(Path(__file__).resolve().parent)
    def test_bin_header_and_size(self):
        self.assertEqual(struct.unpack_from('<IIII',self.img),(0x31444B50,len(self.img),0x2000c010,0))
        self.assertLessEqual(((len(self.img)+127)//128)*128,0x3000)
        self.assertEqual(self.path.read_bytes(),self.img)
    def test_12_phases_final_pattern_and_gpio_id(self):
        s=Pmod0Sim(self.img).run()
        self.assertTrue(s.stopped)
        writes=[value for addr,value in s.writes if addr==P0_OUT]
        self.assertEqual(writes,[0,255,85,170,*[1<<i for i in range(8)],85])
        self.assertEqual(s.mem[P0_OUT],85)
        self.assertTrue(all(a==P0_OUT for a,_ in s.writes))
        self.assertEqual(s.mem[0x80000020],0x55)
        self.assertEqual(s.mem[0x80000030],0xaa)
        text=s.uart.decode('ascii')
        for i in range(1,13): self.assertIn(f'P0 {i:02d}/12',text)
        self.assertIn('DIGITAL READBACK OK',text)
        self.assertIn('PMOD0 OUT:',s.txt(3,4,11))
        self.assertIn('RESULT: DIGITAL READBACK OK',s.txt(17,4,54))
        self.assertIn('01010101',s.txt(3,4+len('PMOD0 OUT: '),8))
        self.assertIn('10101010',s.txt(3,4+len('PMOD0 OUT: 00000000   PIN IN: '),8))
        print('FIRST_RUN_STEPS',s.steps,'PMOD0_WRITES',len(s.writes))
    def test_second_run_latch_flip(self):
        first=Pmod0Sim(self.img).run()
        second=Pmod0Sim(self.img,initial=first.mem).run()
        self.assertEqual(first.mem[P0_OUT],85)
        self.assertEqual(second.mem[P0_OUT],170)
        self.assertIn('DIGITAL READBACK OK',second.uart.decode())
    def test_wrong_bitstream_id_produces_no_gpio_writes(self):
        s=Pmod0Sim(self.img,id=0).run()
        self.assertTrue(s.stopped)
        self.assertEqual(s.writes,[])
        self.assertEqual(s.mem,s.initial)
        self.assertIn('wrong GPIO_ID',s.uart.decode())
    def test_pin_readback_mismatch_switches_off(self):
        s=Pmod0Sim(self.img,mismatch=True).run()
        self.assertTrue(s.stopped)
        self.assertEqual(s.mem[P0_OUT],0)
        self.assertIn('READBACK MISMATCH',s.uart.decode())
        self.assertIn('PORT0 SET TO OFF',s.txt(17,4,53))
        self.assertEqual(s.mem[0x80000020],0x55)
    def test_all_off_binary(self):
        offpath, offimg=build_off(Path(__file__).resolve().parent)
        self.assertEqual(struct.unpack_from('<IIII',offimg),(0x31444B50,len(offimg),0x2000C010,0))
        led_on=Pmod0Sim(self.img).run()
        off=Pmod0Sim(offimg,initial=led_on.mem).run()
        self.assertTrue(off.stopped)
        self.assertEqual(off.mem[P0_OUT],0)
        self.assertEqual(off.writes,[(P0_OUT,0)])
        self.assertIn('physical HIGH',off.uart.decode())
        guard=Pmod0Sim(offimg,id=0).run()
        self.assertEqual(guard.writes,[])
        self.assertEqual(guard.mem,guard.initial)
    def test_repeat_reload_same_image(self):
        s=Pmod0Sim(self.img).run()
        replay=Pmod0Sim(self.img).run()
        self.assertEqual(s.uart,replay.uart)
        self.assertEqual(s.mem,replay.mem)

if __name__=='__main__': unittest.main(verbosity=2)
