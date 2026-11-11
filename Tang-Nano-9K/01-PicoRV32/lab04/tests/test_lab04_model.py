#!/usr/bin/env python3
"""LAB-04 pure-Python RV32I firmware model; NOT an RTL or HDMI board test."""
from __future__ import annotations

import collections
import hashlib
import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location('lab04_assembler', ROOT / 'tools' / 'build_rom.py')
assembler = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(assembler)


def sign(value: int, bits: int) -> int:
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


class CpuModel:
    """Abstract *instruction-level* RV32I subset with ideal instantaneous MMIO.

    Deliberately not a PicoRV32 timing simulator: no UART frame/latency modelling,
    no prefetch, and no HDMI clock or Gowin primitives.
    """
    def __init__(self, rom: list[int], inputs: str = ''):
        self.rom = rom
        self.pc = 0
        self.regs = [0] * 32
        self.rx = collections.deque(inputs.encode('ascii'))
        self.tx = bytearray()
        self.leds = 0
        self.led_writes = []
        self.steps = 0
        self.rx_reads = 0
        self.ram = [0] * 256
        self.video = [0] * 16
        self.video_events = []
        self.video_frames = []

    def read(self, addr: int) -> int:
        if 0x4000 <= addr < 0x4400 and addr % 4 == 0:
            return self.ram[(addr-0x4000)//4]
        if addr == 0x20000004:
            return self.steps
        if addr >= 0x20000100 and addr <= 0x2000013c and not (addr & 3):
            return self.video[(addr - 0x20000100) // 4]
        if addr == 0x20000000:
            return self.leds
        if addr == 0x20000014:
            return 1
        if addr == 0x20000018:
            if self.rx:
                self.rx_reads += 1
                return self.rx.popleft()
            return 0
        if addr == 0x2000001c:
            return 1 if self.rx else 0
        raise AssertionError(f'unmapped read 0x{addr:08x}')

    def write(self, addr: int, value: int) -> None:
        if 0x4000 <= addr < 0x4400 and addr % 4 == 0:
            self.ram[(addr-0x4000)//4] = value & 0xffffffff
            return
        if addr >= 0x20000100 and addr <= 0x2000013c and not (addr & 3):
            ix = (addr - 0x20000100) // 4
            if ix not in (*range(0,6), *range(8,14),15):
                raise AssertionError(f'reserved video MMIO index {ix}')
            self.video[ix] = value & 0xffffff
            self.video_events.append((ix, value & 0xffffff))
            if ix == 15:
                self.video_frames.append(tuple(self.video))
            return
        if addr == 0x20000000:
            self.leds = value & 63
            self.led_writes.append(self.leds)
        elif addr == 0x20000010:
            if value > 255:
                raise AssertionError('UART writes must use low byte')
            self.tx.append(value)
        else:
            raise AssertionError(f'unmapped write 0x{addr:08x}')

    def step(self) -> None:
        if self.pc & 3 or not 0 <= self.pc < len(self.rom) * 4:
            raise AssertionError(f'invalid PC 0x{self.pc:x}')
        word = self.rom[self.pc >> 2]
        op = word & 127
        rd = word >> 7 & 31
        f3 = word >> 12 & 7
        rs1 = word >> 15 & 31
        rs2 = word >> 20 & 31
        s = self.regs
        next_pc = self.pc + 4
        if op == 0x37:
            s[rd] = word & 0xfffff000
        elif op == 0x13:
            imm = sign(word >> 20, 12)
            if f3 == 0:
                s[rd] = (s[rs1] + imm) & 0xffffffff
            elif f3 == 4:
                s[rd] = s[rs1] ^ (imm & 0xffffffff)
            elif f3 == 1 and ((word >> 25) & 127) == 0:
                s[rd] = (s[rs1] << (imm & 31)) & 0xffffffff
            elif f3 == 7:
                s[rd] = s[rs1] & (imm & 0xffffffff)
            elif f3 == 5 and ((word >> 25) & 127) == 0:
                s[rd] = s[rs1] >> (imm & 31)
            else:
                raise AssertionError('unexpected I op')
        elif op == 0x33 and f3 == 0 and ((word >> 25) & 127) in (0, 32):
            if ((word >> 25) & 127) == 32:
                s[rd] = (s[rs1] - s[rs2]) & 0xffffffff
            else:
                s[rd] = (s[rs1] + s[rs2]) & 0xffffffff
        elif op == 0x03 and f3 == 2:
            addr = (s[rs1] + sign(word >> 20, 12)) & 0xffffffff
            s[rd] = self.read(addr)
        elif op == 0x23 and f3 == 2:
            imm = ((word >> 25) << 5) | ((word >> 7) & 31)
            addr = (s[rs1] + sign(imm, 12)) & 0xffffffff
            self.write(addr, s[rs2])
        elif op == 0x63 and f3 in (0, 1):
            imm = ((word >> 31) << 12 | ((word >> 7) & 1) << 11 |
                   ((word >> 25) & 63) << 5 | ((word >> 8) & 15) << 1)
            equal = s[rs1] == s[rs2]
            if equal == (f3 == 0):
                next_pc = (self.pc + sign(imm, 13)) & 0xffffffff
        elif op == 0x6f:
            imm = ((word >> 31) << 20 | ((word >> 12) & 255) << 12 |
                   ((word >> 20) & 1) << 11 | ((word >> 21) & 1023) << 1)
            if rd:
                s[rd] = next_pc
            next_pc = (self.pc + sign(imm, 21)) & 0xffffffff
        elif op == 0x67 and f3 == 0:
            imm = sign(word >> 20, 12)
            target = (s[rs1] + imm) & ~1
            if rd:
                s[rd] = next_pc
            next_pc = target
        else:
            raise AssertionError(f'unsupported instruction {word:08x} at PC={self.pc:04x}')
        self.pc = next_pc
        self.regs[0] = 0
        self.steps += 1

    def run(self, limit: int = 1000000) -> str:
        instructions, labels = assembler.parse_source()
        idle_anchor = labels['poll']
        consecutive_idle = 0
        for _ in range(limit):
            if self.pc == idle_anchor and not self.rx and self.tx.endswith(b'PiKoSoL> '):
                consecutive_idle += 1
                if consecutive_idle >= 2:
                    return self.tx.decode('ascii')
            self.step()
        raise AssertionError(f'ROM did not reach idle prompt in {limit} instructions; '
                             f'pc=0x{self.pc:x} output={bytes(self.tx)!r}')


class Lab0432ShellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.hex_data, cls.rtl_data, cls.meta_data, cls.meta = assembler.build()
        cls.words = [int(w, 16) for w in cls.hex_data.decode('ascii').splitlines()]

    def run_cpu(self, inputs='', limit=1000000):
        cpu = CpuModel(self.words, inputs)
        return cpu, cpu.run(limit=limit)

    def test_rom_reproducible_and_bram(self):
        self.assertEqual((ROOT/'firmware/lab04_boot.hex').read_bytes(), self.hex_data)
        self.assertEqual((ROOT/'rtl/lab04_boot_rom.v').read_bytes(), self.rtl_data)
        self.assertEqual((ROOT/'firmware/lab04_rom_meta.json').read_bytes(), self.meta_data)
        self.assertEqual(len(self.words),4096)
        self.assertLess(self.meta['active_instructions'],4096)
        self.assertIn('$readmemh("lab04_boot.hex", rom)', self.rtl_data.decode())

    def test_boot_console_and_graphics_safe_defaults(self):
        cpu, out=self.run_cpu()
        self.assertIn('PiKoSoL INTERACTIVE SHELL v0.2.0',out)
        self.assertIn('PicoRV32 / Tang Nano 9K',out)
        self.assertTrue(out.endswith('PiKoSoL> '))
        self.assertEqual(cpu.video[0],100)
        self.assertEqual(cpu.video[1],180)
        self.assertEqual(cpu.video[8],280)
        self.assertEqual(cpu.video[9],212)
        self.assertEqual(cpu.leds,0)
        self.assertTrue(out.startswith('\x0e\x0c'))

    def test_help_info_mem_case_insensitive(self):
        cpu, out=self.run_cpu('help\rinfo\rmem\r')
        self.assertIn('HELP INFO MEM LED N|? GFX TERM CLS',out)
        self.assertIn('PiKoSoL LAB-04.3.2',out)
        self.assertIn('ROM 16KiB',out)
        self.assertIn('RAM 1KiB',out)
        self.assertEqual(out.count('PiKoSoL> '),4)

    def test_led_count_and_query(self):
        cpu, out=self.run_cpu('led 3\rLED ?\rLED 0\r')
        self.assertIn('C=3\r\n',out)
        self.assertIn('M=07\r\n',out)
        self.assertIn('C=0\r\n',out)
        self.assertEqual(cpu.leds,0)

    def test_legacy_shortcuts_are_enter_terminated(self):
        cpu, out=self.run_cpu('A\rll\rG\r3\r?\r')
        # `ll` is not a legacy shortcut, and must not partially execute.
        self.assertIn('ERR: UNKNOWN',out)
        self.assertEqual(cpu.video[0],100)
        self.assertEqual(cpu.video[4],0x00ff00)
        self.assertEqual(cpu.leds,7)

    def test_modes_objects_move_boundaries_and_color(self):
        sequence='gfx\robj b\rmove j\rcolor g\rsize +\rterm\r'
        cpu, out=self.run_cpu(sequence)
        self.assertIn('MODE: GRAPHICS',out)
        self.assertIn('MODE: TERMINAL',out)
        self.assertIn('V\r\n',out)
        self.assertIn('\x0f',out)
        self.assertIn('\x0e',out)
        self.assertEqual(cpu.video[8],272)
        self.assertEqual(cpu.video[10],88)
        self.assertEqual(cpu.video[12],0x00ff00)
        self.assertGreaterEqual(len(cpu.video_frames),4)

    def test_backspace_crlf_and_ctrl_p_recall(self):
        cpu,out=self.run_cpu('helx\x08p\r\n\x10\r')
        self.assertIn('HELP INFO MEM',out)
        self.assertEqual(out.count('HELP INFO MEM'),2)
        self.assertIn('\x08 \x08',out)

    def test_invalid_cmd_argument_and_overlong_line(self):
        cpu,out=self.run_cpu('helpx\rled 9\r'+('Z'*55)+'\r')
        self.assertIn('ERR: UNKNOWN',out)
        self.assertIn('ERR: ARGUMENT',out)
        self.assertIn('\x07',out)
        self.assertEqual(cpu.leds,0)
        self.assertTrue(out.endswith('PiKoSoL> '))

    def test_live_keys_moves_rectangles_without_enter_and_term_returns(self):
        # Raw control is opt-in after entering graphics view; no accidental
        # single-byte LED or movement commands during line editing.
        cpu, out = self.run_cpu('gfx\rkeys\rjjjkkkT')
        self.assertIn('LIVE KEYS', out)
        self.assertIn('MODE: TERMINAL', out)
        self.assertTrue(out.endswith('PiKoSoL> '))
        self.assertEqual(cpu.video[0], 76)  # 100 - 3 * 8
        self.assertEqual(cpu.video[1], 204) # 180 + 3 * 8
        self.assertGreaterEqual(len(cpu.video_frames), 7)

    def test_live_key_boundary_and_selection(self):
        cpu, out = self.run_cpu('gfx\rkeys\r' + 'j'*40 + 'BjjT', limit=1500000)
        self.assertGreaterEqual(cpu.video[0], 32)
        self.assertLessEqual(cpu.video[0] + cpu.video[2], 448)
        self.assertEqual(cpu.video[8], 264) # B moved left twice
        self.assertIn('MODE: TERMINAL', out)

    def test_graphics_clamps(self):
        cpu,out=self.run_cpu('gfx\r'+('MOVE I\r'*20)+('MOVE J\r'*20)+'PANEL\r',limit=1500000)
        self.assertGreaterEqual(cpu.video[0],32)
        self.assertGreaterEqual(cpu.video[1],112)
        self.assertLessEqual(cpu.video[0]+cpu.video[2],448)
        self.assertLessEqual(cpu.video[1]+cpu.video[3],344)
        self.assertIn('| PiKoSoL 640x480',out)

if __name__=='__main__':
    unittest.main(verbosity=2)
