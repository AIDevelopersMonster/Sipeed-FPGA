#!/usr/bin/env python3
"""Host-only machine-code emulator tests. Does not prove physical PMOD function."""
import sys,unittest,struct
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent / 'lib'))
from test_pmod_led16 import Sim
from build_pmod_slow import generate,P1,P2,P3

class ThreePortSim(Sim):
    def __init__(self, image, id=0x47503134, mismatch=False, initial=None):
        super().__init__(image,id=id,mismatch=mismatch,initial=initial or {P1:0x12,P1+8:0,P2:0x33,P2+8:0,P3:0x77,P3+8:0})
        self.cpi=1_000_000
    def rd(self,addr):
        if addr in (P1,P1+8,P2,P2+8,P3,P3+8):return self.mem[addr]
        if addr in (P1+4,P2+4,P3+4):
            b=addr-4
            v=(self.mem[b] | (~self.mem[b+8]&0xff))&0xff
            if self.mismatch and addr==P3+4:return v^1
            return v
        return super().rd(addr)
    def wr(self,addr,val):
        if addr in (P1,P1+8,P2,P2+8,P3,P3+8):
            assert (val&~255)==0,(hex(addr),val)
            self.mem[addr]=val;self.writes.append((addr,val))
        else:return super().wr(addr,val)

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):cls.bin=generate(Path(__file__).parent)
    def test_header_size(self):
        for name,data in self.bin.items():
            assert struct.unpack_from('<IIII',data)==(0x31444b50,len(data),0x2000c010,0)
            assert (len(data)+127)//128*128<=0x3000
            assert data==(Path(__file__).parent/name).read_bytes()
    def test_p23_first_run_latches_alternating(self):
        img=self.bin['TP20_PMOD23_SLOW_VISUAL_LATCH.bin'];s=ThreePortSim(img).run()
        assert s.stopped
        assert [s.mem[P2],s.mem[P3]]==[0xaa,0x55],s.mem
        assert [s.mem[P2+8],s.mem[P3+8]]==[255,255]
        assert (s.mem[P1],s.mem[P1+8])==(0x12,0)
        for p in (P2,P3):
            assert all(v in [x[1] for x in s.writes if x[0]==p] for v in (255,0,170,85))
        out=s.uart.decode('ascii');assert 'MMIO OK' in out,out[-100:]
        for i in range(1,5):assert f'STEP {i}' in out
        print('P23: instructions',s.steps,'LED masks',hex(s.mem[P2]),hex(s.mem[P3]))
    def test_p23_second_run_flips(self):
        img=self.bin['TP20_PMOD23_SLOW_VISUAL_LATCH.bin']
        first=ThreePortSim(img).run()
        second=ThreePortSim(img,initial=first.mem).run()
        assert (second.mem[P2],second.mem[P3])==(0x55,0xaa)
    def test_p1_only(self):
        s=ThreePortSim(self.bin['TP20_PMOD1_SLOW_VISUAL_LATCH.bin']).run()
        assert s.stopped
        assert s.mem[P1]==0xaa and s.mem[P1+8]==255
        assert (s.mem[P2],s.mem[P3])==(0x33,0x77)
        t=ThreePortSim(self.bin['TP20_PMOD1_SLOW_VISUAL_LATCH.bin'],initial=s.mem).run()
        assert t.mem[P1]==0x55
    def test_release_restores_tristate_on_all_three(self):
        start=ThreePortSim(self.bin['TP20_PMOD23_SLOW_VISUAL_LATCH.bin']).run()
        finish=ThreePortSim(self.bin['TP20_PMOD123_RELEASE.bin'],initial=start.mem).run()
        assert all(finish.mem[p]==255 and finish.mem[p+8]==0 for p in (P1,P2,P3))
        assert finish.stopped
    def test_gpio_id_failclosed(self):
        for name,data in self.bin.items():
            s=ThreePortSim(data,id=0).run()
            assert not s.writes,(name,s.writes)
            assert s.mem==s.initial
    def test_readback_fault_reporting(self):
        s=ThreePortSim(self.bin['TP20_PMOD23_SLOW_VISUAL_LATCH.bin'],mismatch=True).run()
        assert 'MMIO MISMATCH' in s.uart.decode('ascii')

if __name__=='__main__':unittest.main(verbosity=2)
