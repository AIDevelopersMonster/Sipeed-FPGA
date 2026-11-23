#!/usr/bin/env python3
"""TP20 PiKoSoL UART uploader and interactive host.

Uses pyserial only for the OS COM port. The XMODEM-128/CRC implementation
is here so the original THLN33 bootloader requires NO modifications.
"""
from __future__ import annotations
import argparse
import hashlib
from pathlib import Path
import sys
import time
import struct

SOH, ACK, NAK, EOT, CAN = 1, 6, 21, 4, 24
PROMPT = b'PiKoSoL> '
MARKER = b'Waiting for host transfer...'


def crc16(data: bytes) -> int:
    c=0
    for b in data:
        c ^= b << 8
        for _ in range(8):
            c = ((c << 1) ^ 0x1021) & 0xffff if c & 0x8000 else (c << 1) & 0xffff
    return c


def read_until(port, goal: bytes, seconds: float, *, echo: bool = True) -> bytes:
    limit = time.monotonic() + seconds
    seen=bytearray()
    while time.monotonic()<limit:
        char=port.read(1)
        if not char:
            continue
        seen.extend(char)
        if echo:
            # Avoid displaying nonprintable control characters in terminal.
            if char == b'\r':
                pass
            elif char == b'\n':
                print()
            elif 32 <= char[0] <= 126:
                print(char.decode('ascii'),end='',flush=True)
        if goal in seen:
            return bytes(seen)
    raise TimeoutError(f'Timeout waiting for {goal!r}; received tail {bytes(seen)[-200:]!r}')


def wait_handshake(port, seconds: float, *, marker: bytes | None = None) -> bytes:
    """Return observed prelude, consuming the terminal's XMODEM CRC 'C'.

    For monitor LOAD, ignore the 'C' characters in words like XMODEM-CRC
    before the unique 'Waiting for host transfer...' banner.
    """
    limit = time.monotonic() + seconds
    seen=bytearray()
    armed=(marker is None)
    while time.monotonic()<limit:
        b=port.read(1)
        if not b:
            continue
        seen.extend(b)
        if not armed:
            if marker in seen:
                armed=True
                seen=bytearray()   # ignore all printed text before marker
            continue
        if b==b'C':
            return bytes(seen)
    raise TimeoutError('No XMODEM-CRC handshake C received. Press S0 on Dock and retry.')


def wait_ctrl(port, seconds: float) -> int:
    limit=time.monotonic()+seconds
    while time.monotonic()<limit:
        b=port.read(1)
        if b and b[0] in (ACK,NAK,CAN):
            return b[0]
        # Bootloader only sends ACK/NAK, not printable progress.
    return -1


def send_xmodem(port, payload: bytes, label: str) -> None:
    if len(payload)==0:
        raise ValueError('Cannot transfer an empty image')
    blocks=(len(payload)+127)//128
    max_blocks = 96 if label == 'demo.bin' else 255
    if blocks > max_blocks:
        raise ValueError(f'{label}: {blocks} blocks exceed limit {max_blocks}')
    print(f'XMODEM-CRC {label}: {len(payload)} bytes / {blocks} blocks')
    for i in range(blocks):
        block=payload[i*128:(i+1)*128].ljust(128,b'\0')
        bno=(i+1)&255
        crc=crc16(block)
        frame=bytes([SOH,bno,255-bno])+block+bytes([crc>>8,crc&255])
        for attempt in range(4):
            port.write(frame)
            ctrl=wait_ctrl(port,6)
            if ctrl==ACK:
                break
            if ctrl==CAN:
                raise RuntimeError(f'XMODEM cancelled by FPGA at block {i+1}')
            if attempt==3:
                raise RuntimeError(f'XMODEM block {i+1} not ACKed ({ctrl}); reset board and retry')
        if (i+1)%16==0 or i+1==blocks:
            print(f'  {i+1}/{blocks} ACK',flush=True)
    for _ in range(3):
        port.write(bytes([EOT]))
        if wait_ctrl(port,6)==ACK:
            print('XMODEM transfer ACK / PASS')
            return
    raise RuntimeError('XMODEM EOT not acknowledged')


def validate_image(path: Path, expected_magic: int, capacity: int) -> bytes:
    data=path.read_bytes()
    if not (20<=len(data)<=capacity):
        raise ValueError(f'{path.name} invalid size {len(data)}')
    magic=struct.unpack_from('<I',data)[0]
    if magic!=expected_magic:
        raise ValueError(f'{path.name} invalid magic {magic:08X} != {expected_magic:08X}')
    expected=struct.unpack_from('<I',data,8 if expected_magic==0x61706766 else 4)[0]
    if expected_magic==0x61706766:
        if expected!=len(data) or len(data)%128:
            raise ValueError('monitor has invalid XMODEM/relaunch length')
    elif expected>len(data) or expected<20:
        raise ValueError('demo has invalid self-declared size')
    print(f'{path.name}: {len(data)} bytes, SHA256 {hashlib.sha256(data).hexdigest()}')
    return data


def expect_prompt(port, seconds=10.0) -> bytes:
    return read_until(port,PROMPT,seconds)


def command(port,text:str,seconds=8.0) -> bytes:
    print(f'\nPC> {text}')
    port.write(text.encode('ascii')+b'\r')
    return expect_prompt(port,seconds)


def demo_load(port,demo:bytes) -> None:
    print('\nPC> LOAD')
    port.write(b'LOAD\r')
    wait_handshake(port,12,marker=MARKER)
    send_xmodem(port,demo,'demo.bin')
    text=expect_prompt(port,12)
    if b'LOAD PASS' not in text:
        raise RuntimeError('Monitor did not confirm LOAD PASS')


def main() -> int:
    parser=argparse.ArgumentParser()
    parser.add_argument('--port',default='COM10')
    parser.add_argument('--baud',type=int,default=115200)
    parser.add_argument('--monitor',type=Path,required=True)
    parser.add_argument('--demo',type=Path,required=True)
    parser.add_argument('--attach',action='store_true',help='Do not upload monitor; connect to running app')
    parser.add_argument('--auto-demo',action='store_true',help='RAMTEST + ADD + LOAD+RUN a second program')
    parser.add_argument('--boot-only',action='store_true',help='Close UART after monitor banner; no interactive PC> prompt')
    args=parser.parse_args()
    monitor=validate_image(args.monitor,0x61706766,0x8000)
    demo=validate_image(args.demo,0x31444b50,0x3000)
    try:
        import serial
    except ImportError as exc:
        raise SystemExit('PySerial is required: python -m pip install pyserial') from exc

    try:
        with serial.Serial(args.port,args.baud,timeout=0.07,write_timeout=7,
                           rtscts=False,dsrdtr=False,xonxoff=False) as port:
            port.dtr=False
            port.rts=False
            print(f'COM OPEN PASS {args.port} {args.baud} 8N1')
            if not args.attach:
                print('Waiting for stock bootloader C. If needed, press Dock S0 once now.')
                wait_handshake(port,18)
                print('Bootloader handshake detected')
                send_xmodem(port,monitor,'monitor.bin')
                text=expect_prompt(port,25)
                if b'PiKoSoL TP20' not in text:
                    raise RuntimeError('No PiKoSoL banner after XMODEM (unexpected firmware)')
            else:
                # Prompt may already have been printed before COM port opened.
                port.write(b'\r')
                expect_prompt(port,8)

            print('\nPiKoSoL monitor active; video and commands run on the FPGA CPU.')
            if args.auto_demo:
                text=command(port,'INFO')
                if b'CPU=PicoRV32' not in text:
                    raise RuntimeError('INFO self-check failed')
                text=command(port,'ADD 00000002 00000003')
                if b'RESULT=0x00000005' not in text:
                    raise RuntimeError('CPU arithmetic self-check failed')
                text=command(port,'RAMTEST',seconds=35)
                if b'RAMTEST PASS' not in text:
                    raise RuntimeError('RAM test self-check failed')
                command(port,'BARS',seconds=20)
                demo_load(port,demo)
                text=command(port,'RUN',seconds=35)
                if b'RULE30 CPU CHECKSUM=0x' not in text or b'RUN RETURNED' not in text:
                    raise RuntimeError('External RV32 program did not execute and return')
                print('\nSERIAL TEST PASS / HDMI STILL REQUIRES VISUAL CONFIRMATION')
            if args.boot_only:
                print('MONITOR_BOOT_PASS / UART CLOSED FOR FILE MANAGER')
                return 0
            print('\nInteractive mode. Commands: HELP INFO ADD ... RAMTEST BARS TEXT ...')
            print('PC-only commands: :DEMO=load+run demo again, :EXIT=close console.')
            while True:
                try:
                    txt=input('\nPC> ').strip()
                except (EOFError,KeyboardInterrupt):
                    break
                if not txt:
                    continue
                if txt.upper() in (':EXIT','EXIT','QUIT'):
                    break
                if txt.upper()==':DEMO':
                    demo_load(port,demo)
                    command(port,'RUN',seconds=35)
                elif txt.upper()=='LOAD':
                    demo_load(port,demo)
                else:
                    command(port,txt)
            print('Console closed. FPGA SRAM is NOT overwritten.')
    except KeyboardInterrupt:
        return 130
    except Exception as exc:
        print(f'ERROR: {exc}',file=sys.stderr)
        print('No Flash writes were requested.',file=sys.stderr)
        return 2
    return 0

if __name__=='__main__':
    raise SystemExit(main())
