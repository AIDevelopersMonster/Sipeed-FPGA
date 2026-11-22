"""Offline verification only; emulator checks writes, guarded entry, ret and ABI preservation."""
from __future__ import annotations
import struct
import unittest
import build_all_led_off as m


def sign(v, bits):
    return v - (1 << bits) if v & (1 << (bits - 1)) else v


class Emulator:
    def __init__(self, raw: bytes, gpio_id: int = m.GPIO_ID_EXPECTED):
        self.code = raw[16:]
        self.gpio_id = gpio_id
        self.regs = [0] * 32
        self.callee = (1,2,8,9,*range(18,28))
        for r in self.callee:
            self.regs[r] = (0x19283746 + r) & 0xFFFFFFFF
        self.before = {r: self.regs[r] for r in self.callee}
        self.mem = {
            m.PMOD0_OUT: 0x55, m.LED_OUT: 0x3F,
            m.PMODS[0]: 0xAA, m.PMODS[0] + 8: 255,
            m.PMODS[1]: 0x55, m.PMODS[1] + 8: 255,
            m.PMODS[2]: 0xAA, m.PMODS[2] + 8: 255,
        }
        self.writes = []
        self.uart = bytearray()
        self.ret = False
        self.steps = 0
    def run(self):
        pc = 0
        while 0 <= pc < len(self.code):
            self.steps += 1
            assert self.steps < 1000
            word, = struct.unpack_from('<I', self.code, pc)
            if word == m.RET:
                self.ret = True
                break
            op = word & 0x7F
            rd = (word >> 7) & 31
            f3 = (word >> 12) & 7
            rs1 = (word >> 15) & 31
            rs2 = (word >> 20) & 31
            nextpc = pc + 4
            if op == 0x37:
                self.regs[rd] = word & 0xFFFFF000
            elif op == 0x13 and f3 == 0:
                imm = sign(word >> 20, 12)
                self.regs[rd] = (self.regs[rs1] + imm) & 0xFFFFFFFF
            elif op == 0x03 and f3 == 2:
                imm = sign(word >> 20, 12)
                addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
                assert addr == m.GPIO_ID_ADDR
                self.regs[rd] = self.gpio_id
            elif op == 0x23 and f3 == 2:
                imm = sign(((word >> 25) << 5) | ((word >> 7) & 31),12)
                addr = (self.regs[rs1] + imm) & 0xFFFFFFFF
                val = self.regs[rs2]
                if addr == m.UART_DATA:
                    assert 0 <= val <= 127
                    self.uart.append(val)
                else:
                    assert addr in self.mem, f'unsafe store 0x{addr:08X}'
                    assert val <= 255
                    self.mem[addr] = val
                    self.writes.append((addr, val))
            elif op == 0x63 and f3 == 0:
                imm = sign((((word >> 31) & 1) << 12) |
                           (((word >> 7) & 1) << 11) |
                           (((word >> 25) & 63) << 5) |
                           (((word >> 8) & 15) << 1), 13)
                if self.regs[rs1] == self.regs[rs2]:
                    nextpc = pc + imm
            else:
                raise AssertionError(f'unknown opcode {word:08X}')
            self.regs[0] = 0
            pc = nextpc
        assert self.ret
        assert all(self.regs[r] == v for r,v in self.before.items())
        return self


class Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.raw = m.make_program()

    def test_header_limit(self):
        assert struct.unpack_from('<IIII', self.raw) == (m.MAGIC, len(self.raw), m.ENTRY, 0)
        assert ((len(self.raw) + 127) // 128) * 128 <= 0x3000

    def test_all_off_registers(self):
        sim = Emulator(self.raw).run()
        assert sim.mem[m.PMOD0_OUT] == 0
        assert sim.mem[m.LED_OUT] == 0
        assert all(sim.mem[p] == 255 and sim.mem[p + 8] == 0 for p in m.PMODS)
        assert 'ALL LED OFF' in sim.uart.decode('ascii')

    def test_safe_register_order(self):
        sim = Emulator(self.raw).run()
        for p in m.PMODS:
            assert sim.writes.index((p + 8, 0)) < sim.writes.index((p, 255))
        assert len(sim.writes) == 8  # onboard, PMOD0, 2 writes per 3 other ports

    def test_wrong_gpio_id_no_writes(self):
        sim = Emulator(self.raw, gpio_id=0).run()
        assert not sim.writes
        assert 'WRONG GPIO_ID' in sim.uart.decode('ascii')

    def test_second_run(self):
        a = Emulator(self.raw).run()
        b = Emulator(self.raw).run()
        b.mem = dict(a.mem)
        b.run()  # idempotent; previous IO states already OFF
        assert b.mem == a.mem


if __name__ == '__main__':
    unittest.main(verbosity=2)
