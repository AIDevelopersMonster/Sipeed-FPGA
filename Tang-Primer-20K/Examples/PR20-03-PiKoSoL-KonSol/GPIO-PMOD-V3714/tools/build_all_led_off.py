#!/usr/bin/env python3
"""Generate a single PiKoSoL TP20 / V3714 GP14 RAM .bin which turns ALL LED outputs off.

Physical Sipeed PMOD-LEDx8 modules are active LOW.
  PMOD0: legacy output is *inverted* in FPGA, so write 0x00 (physical HIGH).
  PMOD1,2,3: set DIR=0 (input / Hi-Z) and OUT=0xFF (safe off latch).
  On-board six LEDs: LED_OUT=0x00 (active HIGH register; physical inversion in FPGA).
No GPIO Flash, FPGA reconfiguration, DDR, timers or GPIO input writes.

The .bin requires the already board-tested PiKoSoL GPIO GP14 firmware and XMODEM loader.
PKD1 app header, entry 0x2000C010. Use File Manager 'Load .bin + RUN'.
"""
from __future__ import annotations
import hashlib
from pathlib import Path
import struct

MAGIC = 0x31444B50  # "PKD1", little-endian
ENTRY = 0x2000C010
MAX_PADDED = 0x3000
GPIO_ID_ADDR = 0x8000005C
GPIO_ID_EXPECTED = 0x47503134  # "GP14"
PMOD0_OUT = 0x80000000
PMODS = (0x80000020, 0x80000030, 0x80000040)
LED_OUT = 0x80000050
UART_DATA = 0x8000000C


def lui(rd: int, upper: int) -> int:
    return ((upper & 0xFFFFF) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs: int, imm: int) -> int:
    assert -2048 <= imm <= 2047
    return ((imm & 0xFFF) << 20) | (rs << 15) | (rd << 7) | 0x13


def lw(rd: int, rs: int, imm: int) -> int:
    assert -2048 <= imm <= 2047
    return ((imm & 0xFFF) << 20) | (rs << 15) | (2 << 12) | (rd << 7) | 0x03


def sw(reg: int, rs: int, imm: int) -> int:
    assert -2048 <= imm <= 2047
    v = imm & 0xFFF
    return ((v >> 5) << 25) | (reg << 20) | (rs << 15) | (2 << 12) | ((v & 31) << 7) | 0x23


def beq(rs1: int, rs2: int, offset: int) -> int:
    assert offset % 2 == 0 and -4096 <= offset < 4096
    v = offset & 0x1FFF
    return (((v >> 12) & 1) << 31 | ((v >> 5) & 63) << 25 |
            rs2 << 20 | rs1 << 15 | ((v >> 1) & 15) << 8 |
            ((v >> 11) & 1) << 7 | 0x63)


RET = 0x00008067  # jalr x0, 0(ra)


class Code:
    def __init__(self):
        self.words: list[int] = []
        self.labels: dict[str, int] = {}
        self.branches: list[tuple[int, int, int, str]] = []

    def emit(self, *words: int):
        self.words.extend(words)

    def li(self, rd: int, value: int):
        value &= 0xFFFFFFFF
        hi = ((value + 0x800) >> 12) & 0xFFFFF
        signed_lo = ((value - (hi << 12) + 0x800) & 0xFFF) - 0x800
        self.emit(lui(rd, hi), addi(rd, rd, signed_lo))

    def label(self, name: str):
        assert name not in self.labels
        self.labels[name] = len(self.words)

    def branch_eq(self, rs1: int, rs2: int, label: str):
        self.branches.append((len(self.words), rs1, rs2, label))
        self.emit(0)

    def uart(self, msg: str):
        for ch in msg:
            code = ord(ch)
            assert 0 <= code <= 127
            self.emit(addi(30, 0, code), sw(30, 29, 0))

    def finish(self):
        for index, rs1, rs2, name in self.branches:
            assert name in self.labels
            self.words[index] = beq(rs1, rs2, 4 * (self.labels[name] - index))
        assert self.words[-1] == RET
        return struct.pack('<' + 'I' * len(self.words), *self.words)


def make_program() -> bytes:
    c = Code()
    # Keep ra=x1, sp=x2 and all ABI callee-saved registers intact.
    c.li(29, UART_DATA)
    c.li(10, GPIO_ID_ADDR)
    c.emit(lw(31, 10, 0))
    c.li(28, GPIO_ID_EXPECTED)
    c.branch_eq(31, 28, 'correct_gpio')
    c.uart('\r\n[ALL LED OFF: WRONG GPIO_ID, NO WRITES]\r\n')
    c.emit(RET)
    c.label('correct_gpio')

    # The legacy PMOD0 pad is inverted: OUT=0 drives all pads HIGH, turning PMOD-LED off.
    c.li(10, PMOD0_OUT)
    c.emit(sw(0, 10, 0))
    # The built-in LEDs use active-HIGH LED_OUT bits.
    c.li(10, LED_OUT)
    c.emit(sw(0, 10, 0))

    # Do not drive external PMOD lines while shutting them down: release to Hi-Z first.
    # The pull-up / LED circuit keeps the external LED module dark without a sink.
    for port in PMODS:
        c.li(10, port)
        c.emit(sw(0, 10, 8))               # DIR=0x00 -> input / Hi-Z
        c.emit(addi(7, 0, 255), sw(7, 10, 0))  # OUT=0xFF -> OFF for next output enable

    c.uart('\r\n[PiKoSoL ALL LED OFF: onboard=00, PMOD0=00, PMOD1-3=Hi-Z]\r\n')
    c.emit(RET)
    program = c.finish()
    return struct.pack('<IIII', MAGIC, 16 + len(program), ENTRY, 0) + program


def main() -> None:
    output = Path(__file__).with_name('TP20_ALL_LED_OFF.bin')
    raw = make_program()
    blocks = (len(raw) + 127) // 128
    assert blocks * 128 <= MAX_PADDED
    assert struct.unpack_from('<IIII', raw) == (MAGIC, len(raw), ENTRY, 0)
    output.write_bytes(raw)
    print('CREATED:', output)
    print('BYTES:', len(raw), 'XMODEM BLOCKS:', blocks)
    print('SHA256:', hashlib.sha256(raw).hexdigest().upper())
    print('BOARD TEST PENDING: run only on known GP14 PiKoSoL FPGA')


if __name__ == '__main__':
    main()
