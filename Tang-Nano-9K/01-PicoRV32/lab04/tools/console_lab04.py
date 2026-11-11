#!/usr/bin/env python3
"""PiKoSoL LAB-04.3.2 UART shell client; sends real CR-terminated CPU commands.

No fake local command interpreter. Exit/quit are PC-side only.
Requires pyserial for --port; --dry-run never opens COM.
"""
from __future__ import annotations
import argparse, sys, time

SHORTCUTS = {
    'mask': 'LED ?', 'query': 'LED ?', 'up': 'MOVE I', 'left': 'MOVE J',
    'down': 'MOVE K', 'right': 'MOVE L',
    'red': 'COLOR R', 'green': 'COLOR G', 'blue': 'COLOR U', 'white': 'COLOR W',
    'wider': 'SIZE +', 'narrower': 'SIZE -', 'panel': 'PANEL',
}


def encode_command(line: str) -> bytes:
    raw = line.strip()
    lower = raw.lower()
    if lower in ('again', 'repeat-last'):
        return b'\x10\r'  # Ctrl-P restores one previous command on CPU
    if lower in SHORTCUTS:
        raw = SHORTCUTS[lower]
    elif lower.startswith('count '):
        fields = lower.split()
        if len(fields) != 2 or fields[1] not in '0123456' or len(fields[1])!=1:
            raise ValueError('count accepts exactly one digit 0..6')
        raw = 'LED ' + fields[1]
    elif lower.startswith('one '):
        fields = lower.split()
        if len(fields) != 2 or fields[1] not in '123456' or len(fields[1])!=1:
            raise ValueError('one accepts exactly one digit 1..6')
        raw = 'abcdef'[int(fields[1])-1]
    elif lower.startswith('obj '):
        fields=lower.split()
        if len(fields)!=2 or fields[1] not in ('a','b'):
            raise ValueError('obj accepts A or B')
        raw='OBJ '+fields[1].upper()
    if len(raw)>47 or not raw.isascii() or any(ord(c)<32 or ord(c)>126 for c in raw):
        raise ValueError('PiKoSoL input must contain at most 47 printable ASCII chars')
    return raw.encode('ascii')+b'\r'


def drain(port, duration: float = 0.35) -> None:
    deadline = time.monotonic()+duration
    while time.monotonic()<deadline:
        chunk=port.read(256)
        if chunk:
            # Control bytes SO/SI/FF are host-side display hints, not commands.
            printable = chunk.replace(b'\x0e',b'').replace(b'\x0f',b'')
            sys.stdout.write(printable.decode('ascii',errors='replace'))
            sys.stdout.flush()


def main()->int:
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--port',default='',help='COM10')
    p.add_argument('--baud',type=int,default=115200)
    p.add_argument('--dry-run',action='store_true')
    args=p.parse_args()
    if args.dry_run:
        for line in ('help','info','mem','led 3','count 6','one 2','gfx',
                     'obj b','left','color g','term','cls','again'):
            print(f'{line:10s} -> {encode_command(line)!r}')
        print('LAB0432_CONSOLE_DRY_RUN_PASS: CR-terminated commands, no COM opened')
        return 0
    if not args.port: p.error('--port is required unless --dry-run')
    try: import serial
    except ImportError:
        print('pyserial missing: python -m pip install pyserial',file=sys.stderr)
        return 2
    try:
        with serial.Serial(args.port,args.baud,timeout=0.04,write_timeout=1) as port:
            print(f'Connected to PiKoSoL at {args.port} {args.baud} 8N1')
            drain(port,0.6)
            print('Use HELP, INFO, MEM, LED 3, GFX, TERM, OBJ B, MOVE J, CLS.')
            print('PC-only aliases: count N, one N, left/right/up/down, again; exit quits.')
            while True:
                try: typed=input('PC> ')
                except (KeyboardInterrupt,EOFError):break
                if typed.strip().lower() in ('exit','quit'):break
                try: command=encode_command(typed)
                except ValueError as e:
                    print(e)
                    continue
                port.write(command)
                port.flush()
                drain(port,0.6)
    except Exception as e:
        print(f'UART error: {e}',file=sys.stderr)
        return 3
    return 0


if __name__=='__main__':raise SystemExit(main())
