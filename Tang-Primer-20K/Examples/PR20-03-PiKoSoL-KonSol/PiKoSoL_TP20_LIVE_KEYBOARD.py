#!/usr/bin/env python3
"""PiKoSoL TP20: live Windows keyboard -> UART (one byte per key).

Printable keys, Backspace and Enter are transmitted immediately. FPGA
handles local echo, command processing, and HDMI. This does not program FPGA.
"""
from __future__ import annotations
import argparse
import sys
import time
from typing import Optional

def encode_key(first: str, extended: Optional[str] = None, *, up_recall: bool = False) -> bytes:
    if first in ('\x00', '\xe0'):
        if up_recall and extended == 'H':
            return b'\x10'
        return b''
    if first in ('\r', '\n'):
        return b'\r'
    if first in ('\x08', '\x7f'):
        return b'\x08'
    if first == '\x10':
        return b'\x10'
    if first == '\t':
        return b''
    if len(first) == 1 and 0x20 <= ord(first) <= 0x7e:
        return first.encode('ascii')
    return b''

def pc_output(data: bytes) -> bytes:
    return bytes(b for b in data if b not in (0x0e, 0x0f, 0x1c, 0x1d))

def selftest() -> int:
    checks = [
        ('H', None, False, b'H'),
        ('E', None, False, b'E'),
        ('L', None, False, b'L'),
        ('P', None, False, b'P'),
        ('\x08', None, False, b'\x08'),
        ('\r', None, False, b'\r'),
        ('\n', None, False, b'\r'),
        ('\x10', None, False, b'\x10'),
        ('\t', None, False, b''),
        ('\xe0', 'K', False, b''),
        ('\xe0', 'H', False, b''),
        ('\xe0', 'H', True, b'\x10'),
        ('\u042f', None, False, b''),
    ]
    for first, ext, recall, expected in checks:
        got = encode_key(first, ext, up_recall=recall)
        assert got == expected, (first, ext, recall, got, expected)
        assert len(got) <= 1, got
    assert b''.join(encode_key(k) for k in 'HELP\r') == b'HELP\r'
    assert b''.join(encode_key(k) for k in 'MEM\b\r') == b'MEM\x08\r'
    assert pc_output(b'ABC\x0e\x0f\x1c\x1d\r\n') == b'ABC\r\n'
    print('LIVE_KEYBOARD_SELFTEST_PASS: immediate bytes, CR, BS, Ctrl-P, no UART opened')
    return 0

def print_bytes(data: bytes) -> None:
    clean = pc_output(data)
    if not clean:
        return
    out = getattr(sys.stdout, 'buffer', None)
    if out is not None:
        out.write(clean)
        out.flush()
    else:
        sys.stdout.write(clean.decode('ascii', errors='replace'))
        sys.stdout.flush()

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port', default='COM10', help='PiKoSoL UART (default COM10)')
    ap.add_argument('--baud', type=int, default=115200, help='PiKoSoL UART rate (default 115200)')
    ap.add_argument('--hdmi-only', action='store_true', help='Read and discard incoming UART text; HDMI only')
    ap.add_argument('--up-recall', action='store_true', help='UP arrow sends Ctrl-P only if FPGA firmware supports it')
    ap.add_argument('--selftest', action='store_true', help='Check key encoding without opening COM')
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.baud <= 0:
        ap.error('baud rate must be positive')
    if not sys.platform.startswith('win'):
        print('LIVE MODE requires a Windows console; --selftest is portable.', file=sys.stderr)
        return 2
    try:
        import msvcrt
    except ImportError as exc:
        print(f'Windows keyboard API unavailable: {exc}', file=sys.stderr)
        return 2
    try:
        import serial
    except ImportError:
        print('Install pyserial: python -m pip install pyserial', file=sys.stderr)
        return 2
    ser = None
    try:
        ser = serial.Serial()
        ser.port = args.port
        ser.baudrate = args.baud
        ser.bytesize = serial.EIGHTBITS
        ser.parity = serial.PARITY_NONE
        ser.stopbits = serial.STOPBITS_ONE
        ser.timeout = 0
        ser.write_timeout = 1.0
        ser.dtr = False
        ser.rts = False
        ser.open()
        print(f'[PC] PiKoSoL live keyboard: {args.port}, {args.baud} 8N1')
        print('[PC] Keys transmit immediately; no local keyboard echo.')
        print('[PC] Enter=CR; Backspace=BS; Ctrl-P=history if supported; Esc=exit PC client.')
        if args.up_recall:
            print('[PC] UP -> Ctrl-P (only for compatible firmware).')
        if args.hdmi_only:
            print('[PC] UART output hidden on PC, visible on HDMI.')
        print('[PC] Type HELP: each character should appear on HDMI BEFORE Enter.')
        sys.stdout.flush()
        while True:
            pending = ser.in_waiting
            if pending:
                chunk = ser.read(min(pending, 4096))
                if not args.hdmi_only:
                    print_bytes(chunk)
            while msvcrt.kbhit():
                first = msvcrt.getwch()
                if first in ('\x1b', '\x1d'):
                    print('\n[PC] Client closed. FPGA remains running.')
                    return 0
                ext = msvcrt.getwch() if first in ('\x00', '\xe0') else None
                payload = encode_key(first, ext, up_recall=args.up_recall)
                if payload:
                    ser.write(payload)
                    ser.flush()
            time.sleep(0.005)
    except KeyboardInterrupt:
        print('\n[PC] Interrupted. FPGA untouched.')
        return 0
    except Exception as exc:
        print(f'\n[PC] UART/keyboard error: {exc}', file=sys.stderr)
        print('[PC] Close other COM clients; verify port and baud.', file=sys.stderr)
        return 3
    finally:
        if ser is not None and ser.is_open:
            ser.close()

if __name__ == '__main__':
    raise SystemExit(main())
