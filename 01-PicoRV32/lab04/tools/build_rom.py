#!/usr/bin/env python3
"""Deterministic RV32I-subset assembler for LAB-04.3.2 (no LAB-03 edits).

Supports lui, add, sub, addi, andi, srli, sw, lw, beq, bne, jal, jalr,
  .match/.verb macros for words, and
  .emit "ASCII\\n"
which expands to one ADDI + JAL to putc per character.
ROM 4096 x 32, with embedded long-branch relocation and sync BRAM.
Usage: python tools/build_rom.py [--check]
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'firmware' / 'lab04_boot.S'
HEX = ROOT / 'firmware' / 'lab04_boot.hex'
RTL = ROOT / 'rtl' / 'lab04_boot_rom.v'
META = ROOT / 'firmware' / 'lab04_rom_meta.json'
CAPACITY = 4096
NOP = 0x00000013
REGS = {f'x{i}': i for i in range(32)}
REGS.update(dict(zip(
    ('zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 '
     's2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6').split(),
    list(range(32)))))
REGS['fp'] = 8


def reg(token: str) -> int:
    if token not in REGS:
        raise ValueError(f'unknown register: {token}')
    return REGS[token]


def signed(value: int, bits: int) -> int:
    if not -(1 << (bits - 1)) <= value < (1 << (bits - 1)):
        raise ValueError(f'immediate {value} is outside signed {bits}-bit range')
    return value & ((1 << bits) - 1)


def address(token: str) -> tuple[int, int]:
    m = re.fullmatch(r'(-?(?:0x[0-9a-fA-F]+|[0-9]+))\(([A-Za-z0-9]+)\)', token)
    if not m:
        raise ValueError(f'expected imm(reg), got {token}')
    return int(m.group(1), 0), reg(m.group(2))


def assemble(tokens: list[str], pc: int, labels: dict[str, int]) -> int:
    op, *a = tokens
    if op == 'lui':
        rd, imm = reg(a[0]), int(a[1], 0)
        if not 0 <= imm < (1 << 20):
            raise ValueError('LUI upper immediate exceeds 20 bits')
        return (imm << 12) | (rd << 7) | 0x37
    if op in ('addi', 'andi', 'srli', 'slli', 'xori'):
        rd, src, imm = reg(a[0]), reg(a[1]), int(a[2], 0)
        if op in ('srli', 'slli'):
            if not 0 <= imm <= 31:
                raise ValueError('SRLI shamt must be 0..31')
            f3 = 5 if op == 'srli' else 1
        else:
            imm = signed(imm, 12)
            f3 = {'addi': 0, 'andi': 7, 'xori': 4}[op]
        return imm << 20 | src << 15 | f3 << 12 | rd << 7 | 0x13
    if op in ('add', 'sub'):
        rd, x, y = reg(a[0]), reg(a[1]), reg(a[2])
        f7 = 0x20 if op == 'sub' else 0
        return f7 << 25 | y << 20 | x << 15 | rd << 7 | 0x33
    if op == 'lw':
        rd, (imm, base) = reg(a[0]), address(a[1])
        return signed(imm, 12) << 20 | base << 15 | 2 << 12 | rd << 7 | 0x03
    if op == 'sw':
        src, (imm, base) = reg(a[0]), address(a[1])
        imm = signed(imm, 12)
        return (imm >> 5) << 25 | src << 20 | base << 15 | 2 << 12 | (imm & 31) << 7 | 0x23
    if op in ('beq', 'bne'):
        x, y, target = reg(a[0]), reg(a[1]), a[2]
        if target not in labels:
            raise ValueError(f'undefined branch target: {target}')
        offset = labels[target] - pc
        if offset & 1:
            raise ValueError('unaligned branch')
        b = signed(offset, 13)
        return (((b >> 12) & 1) << 31 | ((b >> 5) & 63) << 25 | y << 20 |
                x << 15 | (0 if op == 'beq' else 1) << 12 |
                ((b >> 1) & 15) << 8 | ((b >> 11) & 1) << 7 | 0x63)
    if op == 'jal':
        rd, target = reg(a[0]), a[1]
        if target not in labels:
            raise ValueError(f'undefined jump target: {target}')
        offset = labels[target] - pc
        if offset & 1:
            raise ValueError('unaligned JAL')
        j = signed(offset, 21)
        return (((j >> 20) & 1) << 31 | ((j >> 1) & 1023) << 21 |
                ((j >> 11) & 1) << 20 | ((j >> 12) & 255) << 12 | rd << 7 | 0x6f)
    if op == 'jalr':
        rd, (imm, src) = reg(a[0]), address(a[1])
        return signed(imm, 12) << 20 | src << 15 | rd << 7 | 0x67
    raise ValueError(f'unsupported instruction: {op}')


def parse_source() -> tuple[list[tuple[int, list[str]]], dict[str, int]]:
    instructions: list[tuple[int, list[str]]] = []
    labels: dict[str, int] = {}
    for line_no, full in enumerate(SOURCE.read_text(encoding='utf-8').splitlines(), 1):
        line = full.split('#', 1)[0].strip()
        if not line:
            continue
        while re.match(r'^[a-zA-Z_]\w*\s*:', line):
            label, line = line.split(':', 1)
            label = label.strip()
            if label in labels:
                raise ValueError(f'duplicate label {label} at line {line_no}')
            labels[label] = len(instructions) * 4
            line = line.strip()
        if not line:
            continue
        # Deterministic convenience macro; compares normalized word in 32-bit
        # scratch-RAM cells at s8. Match is full string, verb accepts a space
        # (to parse typed arguments) or NUL. Every expansion has a private skip.
        m = re.fullmatch(r'\.(match|verb)\s+"([A-Z]+)"\s*,\s*([A-Za-z_]\w*)', line)
        if m:
            kind, literal, target = m.groups()
            skip = f'__not_command_{len(instructions)}'
            def em(op, *args):
                instructions.append((line_no, [op, *map(str, args)]))
            for offset, ch in enumerate(literal):
                em('lw', 't4', f'{offset*4}(s8)')
                em('addi', 't5', 'zero', ord(ch))
                em('bne', 't4', 't5', skip)
            em('lw', 't4', f'{len(literal)*4}(s8)')
            if kind == 'match':
                em('beq', 't4', 'zero', target)
            else:
                em('beq', 't4', 'zero', target)
                em('addi', 't5', 'zero', 32)
                em('beq', 't4', 't5', target)
            labels[skip] = len(instructions)*4
            continue
        if line.startswith('.emit '):
            literal = line[len('.emit '):].strip()
            payload = json.loads(literal)
            if not isinstance(payload, str) or not payload.isascii():
                raise ValueError(f'.emit must contain ASCII string at line {line_no}')
            for ch in payload:
                instructions.append((line_no, ['addi', 't1', 'zero', str(ord(ch))]))
                instructions.append((line_no, ['jal', 'ra', 'putc']))
            continue
        if line.startswith('.'):
            if line in ('.text', '.globl _start'):
                continue
            raise ValueError(f'unsupported directive at {line_no}: {line}')
        tokens = [p for p in re.split(r'[\s,]+', line) if p]
        instructions.append((line_no, tokens))
    # Use long conditional branches to avoid the RV32I B-type +/-4 KiB
    # reach limit as .emit expands the shell's many output strings. Each
    # original BEQ/BNE becomes an inverted branch over a JAL. The mapper
    # relocates ALL labels after expansion; the inverse skip is only 8 bytes.
    expanded = []
    relocation = {}
    branch_skips = {}
    for pos, (line_no, tokens) in enumerate(instructions):
        relocation[pos * 4] = len(expanded) * 4
        if tokens[0] in ('beq', 'bne'):
            skip_label = f'__far_branch_skip_{pos}'
            inverse = 'bne' if tokens[0] == 'beq' else 'beq'
            expanded.append((line_no, [inverse, tokens[1], tokens[2], skip_label]))
            expanded.append((line_no, ['jal', 'zero', tokens[3]]))
            branch_skips[skip_label] = len(expanded) * 4
        else:
            expanded.append((line_no, tokens))
    relocation[len(instructions)*4] = len(expanded)*4
    labels = {k: relocation[v] for k,v in labels.items()}
    labels.update(branch_skips)
    return expanded, labels


def build() -> tuple[bytes, bytes, bytes, dict[str, object]]:
    instructions, labels = parse_source()
    if not 1 <= len(instructions) <= CAPACITY:
        raise ValueError(f'LAB04 ROM needs {len(instructions)} words; capacity is {CAPACITY}')
    data = []
    for i, (line_no, tokens) in enumerate(instructions):
        try:
            word = assemble(tokens, i * 4, labels)
        except Exception as exc:
            raise ValueError(f'{SOURCE.name}:{line_no}: {tokens}: {exc}') from exc
        data.append(word)
    words = data + [NOP] * (CAPACITY - len(data))
    raw_hex = (''.join(f'{word:08x}\n' for word in words)).encode('ascii')
    rom = [
        '// PiKoSoL LAB-04.3.2 synchronous program ROM, generated from lab04_boot.S.',
        '// 4096x32 BRAM inference; readmemh file staged in work/ for Gowin.',
        'module lab04_boot_rom(input wire clk, input wire [11:0] word_addr, output reg [31:0] rdata);',
        '  reg [31:0] rom [0:4095] /* synthesis syn_romstyle = "block_rom" */;',
        '  initial $readmemh("lab04_boot.hex", rom);',
        '  always @(posedge clk) rdata <= rom[word_addr];',
        'endmodule', ''
    ]
    raw_rtl = ('\n'.join(rom)).encode('ascii')
    meta = dict(schema='LAB0432_ROM_v2', capacity_words=CAPACITY,
                active_instructions=len(data), padding_nop=CAPACITY - len(data),
                source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                rom_sha256=hashlib.sha256(raw_hex).hexdigest(),
                generated_rtl_sha256=hashlib.sha256(raw_rtl).hexdigest(),
                instruction_set=['lui', 'add', 'sub', 'addi', 'andi', 'xori', 'srli', 'slli', 'sw', 'lw', 'beq', 'bne', 'jal', 'jalr'],
                command_contract={'digits_0_to_6': 'LED count (prefix mask)',
                                  'a_to_f': 'single LED 1..6 + Enter', '?': 'readback raw LED mask + Enter', 'A/B': 'select graphics object',
                                  'i/j/k/l': 'move 8 pixels + Enter', 'R/G/U/W': 'object color',
                                  'X/O/K': 'toggle enable, outline, checker',
                                  '+/-': 'width +/-8', 'p': 'ASCII panel to UART and HDMI'})
    raw_meta = (json.dumps(meta, ensure_ascii=False, indent=2) + '\n').encode('utf-8')
    return raw_hex, raw_rtl, raw_meta, meta


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--check', action='store_true', help='Only compare regenerated output; do not modify anything')
    args = ap.parse_args()
    values = build()
    targets = [(HEX, values[0]), (RTL, values[1]), (META, values[2])]
    if args.check:
        for path, expected in targets:
            if not path.is_file() or path.read_bytes() != expected:
                raise SystemExit(f'LAB04_ROM_CHECK_FAIL: stale or missing {path}')
        print('LAB04_ROM_REPRODUCE_PASS:', values[3]['active_instructions'],
              'instructions, SHA256', values[3]['rom_sha256'])
    else:
        for path, data in targets:
            path.write_bytes(data)
        print('LAB04_ROM_BUILD_PASS:', values[3]['active_instructions'],
              'instructions, SHA256', values[3]['rom_sha256'])
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
