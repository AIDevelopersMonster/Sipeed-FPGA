#!/usr/bin/env python3
"""Build a tiny PiKoSoL TP20 RV32I RAM executable without a compiler.

The app writes colored 32-bit text cells to VIDEO=0x30000000, then returns to
PiKoSoL via jalr x0, 0(ra). The 16-byte app header takes its magic from the
board-tested demo.bin. This is a *candidate* until run on the physical board.

Usage:
  python build_hello_rv32i.py --demo C:\\...\\firmware\\demo.bin --output HELLO_TP20.bin
  python build_hello_rv32i.py --selftest
"""
from __future__ import annotations

import argparse
from pathlib import Path
import struct
import sys

SCREEN_WIDTH = 96
SCREEN_HEIGHT = 42
VIDEO_BASE = 0x30000000
APP_ORIGIN = 0x2000C000
MAX_BYTES = 0x3000  # including XMODEM pad, monitor LOAD limit
BANNER = 'PiKoSoL / RV32I / HELLO!'
EXPECTED_DEMO_SHA256 = 'be20fb6ec6d1c7bfe1e9591f0c734649c61d200217f5ebf15800b4f4e681de26'
FG = [11, 14, 10, 13, 15]  # yellow, aqua, lime, magenta, white
BACKGROUND = 4             # navy


def check_imm12(value: int) -> int:
    if not -2048 <= value <= 2047:
        raise ValueError(f'not a signed 12-bit immediate: {value}')
    return value & 0xfff


def lui(rd: int, upper20: int) -> int:
    if not 0 <= upper20 <= 0xfffff:
        raise ValueError('LUI upper20 out of range')
    return ((upper20 & 0xfffff) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs1: int, imm: int) -> int:
    return (check_imm12(imm) << 20) | (rs1 << 15) | (rd << 7) | 0x13


def sw(rs2: int, rs1: int, imm: int) -> int:
    imm = check_imm12(imm)
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (2 << 12) | ((imm & 31) << 7) | 0x23


def ret() -> int:
    return 0x00008067  # jalr zero, 0(ra)


def address_pair(address: int, reg: int) -> list[int]:
    high = (address + 0x800) >> 12
    low = address - (high << 12)
    return [lui(reg, high), addi(reg, reg, low)]


def assemble_banner(message: str = BANNER, row: int = 20, col: int = 30) -> bytes:
    try:
        msg = message.encode('ascii')
    except UnicodeEncodeError as exc:
        raise ValueError('Only ASCII text is supported by this sample') from exc
    if row < 0 or row >= SCREEN_HEIGHT or col < 0 or col + len(msg) > SCREEN_WIDTH:
        raise ValueError('Text does not fit the 96x42 display')
    base = VIDEO_BASE + ((row * SCREEN_WIDTH) + col) * 4
    # t0=x5 -> first video cell; t1=x6 -> color prefix; t2=x7 -> cell data.
    instructions = address_pair(base, 5)
    for pos, ch in enumerate(msg):
        color_word = (FG[pos % len(FG)] << 24) | (BACKGROUND << 16)
        instructions.append(lui(6, color_word >> 12))
        instructions.append(addi(7, 6, ch))
        instructions.append(sw(7, 5, pos * 4))
    instructions.append(ret())
    return b''.join(struct.pack('<I', instruction) for instruction in instructions)


def build(demo: Path, output: Path, message: str = BANNER, *, _test_digest: str | None = None) -> bytes:
    demo = demo.expanduser().resolve()
    if not demo.is_file():
        raise FileNotFoundError(f'Board-tested demo.bin not found: {demo}')
    data = demo.read_bytes()
    if len(data) != 1292:
        raise ValueError('Expected board-tested demo.bin of exactly 1292 bytes')
    import hashlib
    if hashlib.sha256(data).hexdigest() != (_test_digest or EXPECTED_DEMO_SHA256):
        raise ValueError('Board-tested demo.bin SHA256 mismatch; refusing build')
    magic = struct.unpack_from('<I', data)[0]
    if magic in (0, 0xffffffff):
        raise ValueError('demo.bin has no usable app magic')
    instructions = assemble_banner(message)
    # PiKoSoL PKD1 header from the board-tested demo.bin:
    # word0 magic, word1 exact byte length, word2 entry address, word3 reserved.
    # The external THLN33 bootloader ABI is different. The downloaded image is raw binary, not ELF/FPGA .fs.
    payload = struct.pack('<IIII', magic, 16 + len(instructions), APP_ORIGIN + 16, 0) + instructions
    if (len(payload) + 127) // 128 * 128 > MAX_BYTES:
        raise ValueError('Application exceeds mapped RAM window')
    output = output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(payload)
    return payload


def emulate(code: bytes, base: int, max_steps: int = 512):
    """Offline execution of exactly the generated RV32I subset, not a full CPU simulator."""
    regs = [0] * 32
    regs[1] = 0x12345678  # return address supplied by shell RUN caller
    cell_writes = {}
    returned = False
    for idx in range(0, len(code), 4):
        if idx // 4 >= max_steps:
            raise AssertionError('instruction limit')
        word, = struct.unpack_from('<I', code, idx)
        op = word & 0x7f
        rd = (word >> 7) & 31
        rs1 = (word >> 15) & 31
        rs2 = (word >> 20) & 31
        if op == 0x37:  # LUI
            regs[rd] = word & 0xfffff000
        elif op == 0x13:  # ADDI
            imm = (word >> 20) & 4095
            if imm >= 2048:
                imm -= 4096
            regs[rd] = (regs[rs1] + imm) & 0xffffffff
        elif op == 0x23:  # SW
            imm = ((word >> 25) << 5) | ((word >> 7) & 31)
            if imm >= 2048:
                imm -= 4096
            addr = (regs[rs1] + imm) & 0xffffffff
            if addr < VIDEO_BASE or addr >= VIDEO_BASE + 4096 * 4 or addr % 4 != 0:
                raise AssertionError(f'out of range write: 0x{addr:08X}')
            cell_writes[addr] = regs[rs2]
        elif word == 0x00008067:
            returned = True
            break
        else:
            raise AssertionError(f'unsupported/generated instruction: 0x{word:08X}')
        regs[0] = 0
    return returned, cell_writes


def selftest() -> int:
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        folder = Path(td)
        demo = folder / 'demo.bin'
        demo.write_bytes(struct.pack('<IIII', 0x31444b50, 1292, 0x2000c010, 0) + b'\x13\x00\x00\x00' * 319)
        out = folder / 'HELLO.bin'
        payload = build(demo, out, _test_digest=__import__('hashlib').sha256(demo.read_bytes()).hexdigest())
        assert payload == out.read_bytes()
        assert struct.unpack_from('<IIII', payload) == (0x31444b50, len(payload), APP_ORIGIN + 16, 0)
        assert struct.unpack_from('<I', payload, 4)[0] == len(payload)
        did_return, cells = emulate(payload[16:], APP_ORIGIN+16)
        assert did_return and len(cells) == len(BANNER), (did_return, len(cells))
        text = ''.join(chr(cell & 0xff) for cell in cells.values())
        assert text == BANNER, (text, BANNER)
        assert all(((v>>16)&0xff) == BACKGROUND for v in cells.values())
        assert len(payload) <= MAX_BYTES
        print(f'HELLO_RV32I_OFFLINE_PASS: {len(payload)} bytes, {len(cells)} colored HDMI cells, RET to caller')
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--demo', help='Board-tested firmware/demo.bin for magic signature')
    ap.add_argument('--output', default='HELLO_PiKoSoL_TP20.bin')
    ap.add_argument('--text', default=BANNER)
    ap.add_argument('--selftest', action='store_true')
    args = ap.parse_args()
    if args.selftest:
        return selftest()
    if not args.demo:
        ap.error('--demo is required to build a candidate')
    try:
        p = build(Path(args.demo), Path(args.output), args.text)
        print(f'RV32I BIN CANDIDATE: {args.output} / {len(p)} bytes; hardware execution NOT VERIFIED')
        return 0
    except Exception as exc:
        print(f'BUILD FAILED: {exc}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
