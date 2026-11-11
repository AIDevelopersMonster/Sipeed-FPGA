#!/usr/bin/env python3
"""Deterministic firmware MODEL test. This does NOT test Verilog UART timing or FPGA."""
from __future__ import annotations
from pathlib import Path
from lab03_trace_decode import decode, read_rom

BASE = Path(__file__).resolve().parents[1]
ROM = read_rom(BASE/'firmware'/'lab03_boot.hex')
MASK32 = (1 << 32) - 1


def sign(x: int, bits: int) -> int:
    return (x ^ (1 << (bits-1))) - (1 << (bits-1))


class Emu:
    def __init__(self, commands: str):
        self.queue = list(commands.encode('ascii'))
        self.reg = [0] * 32
        self.pc = 0
        self.uart = []
        self.led = 0
        self.events = []
        self.capture = False
        self.trace_done = False
        self.trigger = 0
        self.index = 0
        self.steps = 0

    def read(self, addr: int) -> int:
        if addr == 0x20000000: return self.led
        if addr == 0x20000014: return 1
        if addr == 0x2000001C: return 1 if self.queue else 0
        if addr == 0x20000018:
            ch = self.queue.pop(0) if self.queue else 0
            if 48 <= ch <= 54 and not self.trace_done and not self.capture:
                self.trigger=ch; self.capture=True; self.events=[]
            return ch
        if addr == 0x20000020:
            return (3<<24) | (128<<16) | len(self.events) | (256 if self.trace_done else 0) | (4096 if self.capture else 0)
        if addr == 0x20000024:return self.trigger
        if addr == 0x2000002C:
            cycle,kind,_,_ = self.events[self.index]
            return ((kind & 3) << 16) | (cycle & 65535)
        if addr == 0x20000030:return self.events[self.index][2]
        if addr == 0x20000034:return self.events[self.index][3]
        raise ValueError(f'Unsupported model MMIO read: 0x{addr:08x} pc=0x{self.pc:08x}')

    def write(self, addr: int, value: int):
        if addr==0x20000000:
            self.led=value & 63
            if self.capture:
                self.events.append((self.steps % 65536,2,addr,value))
                self.trace_done=True;self.capture=False
        elif addr == 0x20000010:
            self.uart.append(value & 255)
        elif addr == 0x20000028:
            self.index=value
            if not (0 <= self.index < len(self.events)):
                raise AssertionError(f'Firmware requests invalid event index {self.index}, count={len(self.events)}')
        elif addr == 0x20000038:
            self.events=[];self.capture=False;self.trace_done=False;self.trigger=0;self.index=0
        else:
            raise ValueError(f'Unsupported model MMIO write: 0x{addr:08x}')

    def tick(self):
        if self.pc>=1024 or self.pc %4:
            raise AssertionError(f'bad ROM pc 0x{self.pc:08x}')
        word=ROM[self.pc//4]
        pc0=self.pc
        if self.capture:
            self.events.append((self.steps & 65535,1,self.pc,word))
            if len(self.events)>128:raise AssertionError('firmware-model trace exceeded 128')
        opcode=word&127;rd=(word>>7)&31;rs1=(word>>15)&31;rs2=(word>>20)&31;func=(word>>12)&7
        imm12=sign((word>>20)&4095,12)
        addr=self.reg[rs1]
        self.pc = (self.pc+4)&MASK32
        if opcode==0x37:
            self.reg[rd]=word&0xFFFFF000
        elif opcode==0x13:
            if func==0:self.reg[rd]=(addr+imm12)&MASK32
            elif func==7:self.reg[rd]=addr&(imm12&MASK32)
            elif func==5:self.reg[rd]=(addr>>((word>>20)&31))&MASK32
            else:raise ValueError('unsupported op-imm')
        elif opcode==3 and func==2:
            self.reg[rd]=self.read((addr+imm12)&MASK32)
        elif opcode==0x23 and func==2:
            imm = sign(((word>>25)<<5)|((word>>7)&31),12)
            self.write((addr+imm)&MASK32,self.reg[rs2])
        elif opcode==0x63:
            imm=((word>>31)&1)<<12 | ((word>>7)&1)<<11 | ((word>>25)&63)<<5 | ((word>>8)&15)<<1
            imm=sign(imm,13)
            take = self.reg[rs1]==self.reg[rs2]
            if func==1:take=not take
            if take:self.pc=(pc0+imm)&MASK32
        elif opcode==0x6f:
            imm=((word>>31)&1)<<20 | ((word>>12)&255)<<12 | ((word>>20)&1)<<11 | ((word>>21)&1023)<<1
            self.reg[rd]=self.pc
            self.pc=(pc0+sign(imm,21))&MASK32
        elif opcode==0x67 and func==0:
            pc_next=(addr+imm12)&MASK32
            self.reg[rd]=self.pc
            self.pc=pc_next&~1
        else:
            raise ValueError(f'Unsupported word 0x{word:08x}, PC=0x{pc0:08x}')
        self.reg[0]=0
        self.steps+=1


def run() -> None:
    emulator=Emu('C4TTC1T?')
    completed = 0
    for _ in range(200000):
        emulator.tick()
        wire=bytes(emulator.uart).decode('ascii')
        if wire.count('Z\n')==3 and wire.endswith('L=1\n'):
            break
    else:
        raise AssertionError(f'firmware did not finish: PC=0x{emulator.pc:08x}, chars={len(emulator.uart)}, last={wire[-130:]}')
    if emulator.led != 1:raise AssertionError(f'bad final LED state {emulator.led}')
    if not wire.startswith('READY\nC\nL=4\n'):
        raise AssertionError('LAB-02 compatibility banner / LED ack broken')
    snippets=[]
    lines=wire.splitlines(keepends=True)
    i=0
    while i<len(lines):
        if lines[i].startswith('T3:'):
            start=i
            while i<len(lines) and lines[i]!='Z\n':i+=1
            if i>=len(lines):raise AssertionError('no terminator')
            trace=decode(''.join(lines[start:i+1]),ROM)
            snippets.append((trace,''.join(lines[start:i+1])))
        i+=1
    if len(snippets)!=3:raise AssertionError(f'expected 3 snapshots, got {len(snippets)}')
    if [s[0]['command'] for s in snippets]!=['4','4','1']:
        raise AssertionError('snapshot command mismatch')
    if snippets[0][1]!=snippets[1][1]:
        raise AssertionError('second read should match first immutable capture')
    if snippets[0][0]['events'][-1]['value']!='0x00000008':
        raise AssertionError('L4 snapshot missing')
    if snippets[2][0]['events'][-1]['value']!='0x00000001':
        raise AssertionError('L1 snapshot missing')
    print(f'LAB03_2_FIRMWARE_MODEL_PASS: 202 instructions, 3 consistent T3 frames, commands 4/4/1, '
          f'first events={snippets[0][0]["count"]}, C rearm, ROM checks, L=4/L=1')


if __name__=='__main__':run()
