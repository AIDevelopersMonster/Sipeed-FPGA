#!/usr/bin/env python3
"""Offline RV32I subset interpreter for PiKoSoL GPIO LIVE .bin."""
import hashlib
import struct
import unittest
from pathlib import Path
from build_gpio_live import make, ENTRY, VRAM, LED_REG, UART_DATA, GPIO_ID

MASK = 0xffffffff

def sext(n,bits):
    return n-(1<<bits) if n&(1<<(bits-1)) else n

class Emulator:
    def __init__(self, data, input_events=None, gpio_id=GPIO_ID, cycles_per_instruction=20_000):
        self.data = data
        self.events = input_events or [(0,0,0)]
        self.gpio_id = gpio_id
        self.cycles_per_instruction = cycles_per_instruction
        self.cycle = 0
        self.reg = [0]*32
        self.reg[1] = 0xCAFEBABE
        self.pc = 0
        self.video = {}
        self.led_writes = []
        self.uart = bytearray()
        self.steps = 0

    def get_inputs(self):
        value = self.events[0][1:]
        for t,k,d in self.events:
            if self.cycle >= t:
                value = k,d
        return value

    def read32(self, addr):
        if addr == LED_REG + 12:
            return self.gpio_id
        k,d = self.get_inputs()
        if addr == LED_REG+4:
            return k
        if addr == LED_REG+8:
            return d
        raise AssertionError(f'UNSAFE READ 0x{addr:08x}')

    def store32(self, addr, val):
        if addr == LED_REG:
            assert val & ~0x3f == 0, val
            self.led_writes.append((self.cycle,val))
        elif addr == UART_DATA:
            assert 0 <= val <= 255, val
            self.uart.append(val)
        elif VRAM <= addr < VRAM+96*42*4 and (addr&3)==0:
            self.video[addr]=val
        else:
            raise AssertionError(f'UNSAFE WRITE 0x{addr:08x}=0x{val:08x}')

    def run(self, step_limit=600_000):
        code=self.data[16:]
        while 0<=self.pc<len(code):
            self.steps+=1
            assert self.steps < step_limit, 'STEP LIMIT'
            raw,=struct.unpack_from('<I',code,self.pc)
            op=raw&127; rd=(raw>>7)&31; f3=(raw>>12)&7; rs=(raw>>15)&31; rb=(raw>>20)&31
            next_pc=self.pc+4
            self.cycle+=self.cycles_per_instruction
            if raw == 0x00008067:
                assert self.reg[1]==0xCAFEBABE
                return self
            elif op == 0x37:
                self.reg[rd]=raw&0xfffff000
            elif op == 0x13:
                imm=sext(raw>>20,12)
                if f3==0:
                    self.reg[rd]=(self.reg[rs]+imm)&MASK
                elif f3==7:
                    self.reg[rd]=self.reg[rs] & imm & MASK
                elif f3==5:
                    assert (raw>>25)==0
                    self.reg[rd]=self.reg[rs]>>(rb&31)
                elif f3==1:
                    assert (raw>>25)==0
                    self.reg[rd]=(self.reg[rs]<<(rb&31))&MASK
                else:
                    raise AssertionError('OPIMM unsupported')
            elif op==0x33:
                if f3==0 and raw>>25 == 0x20:
                    self.reg[rd]=(self.reg[rs]-self.reg[rb])&MASK
                elif f3==6 and raw>>25==0:
                    self.reg[rd]=self.reg[rs] | self.reg[rb]
                else:
                    raise AssertionError('OP unsupported')
            elif op==0x03:
                assert f3==2
                addr=(self.reg[rs]+sext(raw>>20,12))&MASK
                self.reg[rd]=self.read32(addr)
            elif op==0x23:
                assert f3==2
                offset=sext(((raw>>25)<<5)|((raw>>7)&31),12)
                addr=(self.reg[rs]+offset)&MASK
                self.store32(addr,self.reg[rb])
            elif op==0x63:
                imm=sext((((raw>>31)&1)<<12)|(((raw>>7)&1)<<11)|(((raw>>25)&63)<<5)|(((raw>>8)&15)<<1),13)
                a,b=self.reg[rs],self.reg[rb]
                take={0:a==b,1:a!=b,6:a<b,7:a>=b}.get(f3)
                assert take is not None
                if take: next_pc=self.pc+imm
            elif op==0x6f:
                assert rd==0
                imm=sext((((raw>>31)&1)<<20)|(((raw>>12)&255)<<12)|(((raw>>20)&1)<<11)|(((raw>>21)&1023)<<1),21)
                next_pc=self.pc+imm
            elif op==0x73:
                assert f3==2 and (raw>>20)==0xC00 and rs==0
                self.reg[rd]=self.cycle&MASK
            else:
                raise AssertionError(f'UNHANDLED INSTRUCTION 0x{raw:08X} pc={self.pc}')
            self.reg[0]=0
            self.pc=next_pc
        raise AssertionError('NO RET')

    def string(self,row,col,n):
        return ''.join(chr(self.video.get(VRAM+4*(96*row+col+i),0)&255) for i in range(n))

class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        p=Path(__file__).with_name('TP20_GPIO_KEYS_DIP_LED_TERMINAL_5S.bin')
        cls.image=make(p)

    def test_image_header_and_size(self):
        data=self.image
        self.assertEqual(struct.unpack_from('<IIII',data),(0x31444B50,len(data),ENTRY,0))
        self.assertLessEqual(((len(data)+127)//128)*128,12*1024)
        self.assertEqual(len(data)%4,0)
        self.assertEqual(len(hashlib.sha256(data).hexdigest()),64)

    def test_dynamic_inputs_outputs_uart_hdmi_return(self):
        sim=Emulator(self.image,[(0,0,0), (45_000_000,1,1), (130_000_000,4,8), (220_000_000,2,3)],cycles_per_instruction=20_000).run()
        print('Simulation steps',sim.steps,'cycles',sim.cycle)
        print(sim.uart.decode('ascii',errors='replace')[-900:])
        seen=[v for _,v in sim.led_writes]
        self.assertIn(0,seen)
        self.assertIn(9,seen) # S2 and SW2
        self.assertIn(4,seen) # S5 + SW5 only
        self.assertIn(26,seen) # S3 + SW2 + SW3
        self.assertTrue(sim.string(2,4,22).startswith('PiKoSoL TP20'))
        self.assertIn('DONE: RETURN TO PiKoSoL',sim.string(24,4,54))
        self.assertIn('GPIO S2=1',sim.uart.decode('ascii'))
        self.assertIn('GPIO LIVE END',sim.uart.decode('ascii'))
        self.assertLessEqual(sim.cycle, 360_000_000)

    def test_wrong_id_exits_without_toggling_led(self):
        sim=Emulator(self.image,gpio_id=0,cycles_per_instruction=1000).run()
        self.assertEqual(sim.led_writes,[])
        self.assertIn('GPIO ERROR',sim.uart.decode('ascii'))
        self.assertIn('GPIO ID MISMATCH',sim.string(4,4,55))

    def test_start_clock_wrap(self):
        sim=Emulator(self.image,[(0,1,15)],cycles_per_instruction=500_000)
        sim.cycle=0xfffffff0-15_000_000
        sim.run()
        self.assertIn('GPIO LIVE END',sim.uart.decode('ascii'))

if __name__=='__main__':
    unittest.main(verbosity=2)
