#!/usr/bin/env python3
"""LAB-02 RV32I+MMIO *abstract* firmware test. NOT RTL or timing proof."""
from __future__ import annotations
from collections import deque
from pathlib import Path

MASK = 0xFFFFFFFF


def sext(v: int, n: int) -> int:
    v &= (1 << n) - 1
    return v if v < (1 << (n - 1)) else v - (1 << n)


def check_rom(root: Path) -> list[int]:
    # The original pinned assembler is still the single source of truth.
    from assemble import assemble_instruction, parse_lines
    insns, labels = parse_lines(root / 'firmware' / 'boot.S')
    machine = [assemble_instruction(tokens, i * 4, labels)
               for i, (_, tokens) in enumerate(insns)]
    words = [int(s, 16) for s in (root / 'firmware' / 'boot.hex').read_text().splitlines()]
    assert words[:len(machine)] == machine
    assert len(words) == 256
    return words


def simulate(words: list[int], incoming: bytes, expected: bytes) -> None:
    regs = [0] * 32
    pc = 0
    incoming_q = deque(incoming)
    outgoing = bytearray()
    led_writes: list[int] = []
    leds = 0
    for step in range(100000):
        assert pc % 4 == 0 and 0 <= pc // 4 < 256, f'bad PC {pc:#x}'
        w = words[pc // 4]
        op = w & 127
        rd, rs1, rs2 = (w >> 7) & 31, (w >> 15) & 31, (w >> 20) & 31
        f3 = (w >> 12) & 7
        next_pc = pc + 4
        if op == 0x37:
            regs[rd] = w & 0xFFFFF000
        elif op == 0x13:
            imm = sext(w >> 20, 12)
            if f3 == 0:
                regs[rd] = (regs[rs1] + imm) & MASK
            elif f3 == 7:
                regs[rd] = regs[rs1] & imm
            elif f3 == 5:
                regs[rd] = regs[rs1] >> (imm & 31)
            else:
                raise AssertionError(f'unsupported I funct3={f3}')
        elif op == 0x03:
            assert f3 == 2
            addr = (regs[rs1] + sext(w >> 20, 12)) & MASK
            if addr == 0x20000000:
                value = leds
            elif addr == 0x20000014:  # simplified TX ready
                value = 1
            elif addr == 0x20000018:  # pop FIFO
                value = incoming_q.popleft() if incoming_q else 0
            elif addr == 0x2000001C:  # RX status: bit0
                value = int(bool(incoming_q))
            else:
                raise AssertionError(f'unmapped MMIO read addr={addr:#x}')
            regs[rd] = value
        elif op == 0x23:
            assert f3 == 2
            imm = sext(((w >> 25) << 5) | ((w >> 7) & 31), 12)
            addr = (regs[rs1] + imm) & MASK
            value = regs[rs2]
            if addr == 0x20000000:
                leds = value & 63
                led_writes.append(leds)
            elif addr == 0x20000010:
                outgoing.append(value & 255)
            else:
                raise AssertionError(f'unmapped MMIO store addr={addr:#x}')
        elif op == 0x63:
            imm = ((w >> 31) << 12) | (((w >> 7) & 1) << 11) | \
                  (((w >> 25) & 63) << 5) | (((w >> 8) & 15) << 1)
            match = (regs[rs1] == regs[rs2]) if f3 == 0 else (regs[rs1] != regs[rs2])
            assert f3 in (0, 1)
            if match:
                next_pc = pc + sext(imm, 13)
        elif op == 0x6F:
            imm = (((w >> 31) & 1) << 20) | (((w >> 12) & 255) << 12) | \
                  (((w >> 20) & 1) << 11) | (((w >> 21) & 1023) << 1)
            regs[rd] = next_pc
            next_pc = pc + sext(imm, 21)
        elif op == 0x67:
            assert f3 == 0
            target = (regs[rs1] + sext(w >> 20, 12)) & MASK
            regs[rd] = next_pc
            next_pc = target & ~1
        else:
            raise AssertionError(f'illegal opcode {op:#x} at {pc:#x}')
        regs[0] = 0
        pc = next_pc
        if bytes(outgoing) == expected and not incoming_q:
            assert led_writes == [0, 0, 1, 8, 32, 0], led_writes
            assert leds == 0
            print(f'LAB02_FIRMWARE_MODEL_PASS: {step+1} instructions; '
                  f'TX={outgoing!r}; LED writes={led_writes}')
            return
        assert expected.startswith(outgoing), f'unexpected TX prefix: {outgoing!r}'
    raise AssertionError(f'model timeout: PC={pc:#x}, RX remaining={len(incoming_q)}, TX={outgoing!r}')


if __name__ == '__main__':
    root = Path(__file__).resolve().parents[1]
    program = check_rom(root)
    simulate(program, b'0146?X\r\n0', b'READY\nL=0\nL=1\nL=4\nL=6\nL=6\nE\nL=0\n')
