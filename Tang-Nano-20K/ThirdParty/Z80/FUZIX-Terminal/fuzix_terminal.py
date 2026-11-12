#!/usr/bin/env python3
"""Interactive UART terminal for nano-Z80 CP/Mish / FUZIX.

Windows stdlib + pyserial. Does not touch FPGA flash or raw SD storage.
All bytes sent to the board are direct user keystrokes.
"""
from __future__ import annotations

import argparse
import datetime
import os
from pathlib import Path
import re
import sys

DEFAULT_PORT = 'COM25'
BAUDRATE = 115200
CPM_PROMPT = re.compile(rb'(?:^|[\r\n])\s*[A-P]>\s*$', re.I)
FUZIX_LOGIN = re.compile(rb'login:\s*$', re.I)
ANSI_ESCAPE = re.compile(rb'\x1b\[[0-?]*[ -/]*[@-~]')
KEYMAP = {
    'H': b'\x1b[A',  # up
    'P': b'\x1b[B',  # down
    'K': b'\x1b[D',  # left
    'M': b'\x1b[C',  # right
    'G': b'\x1b[H',  # home
    'O': b'\x1b[F',  # end
    'S': b'\x1b[3~', # delete
}


def classify_tail(data: bytes) -> str:
    """Classify a visible, ANSI-stripped UART tail, without sending commands."""
    plain = ANSI_ESCAPE.sub(b'', data[-2048:]).rstrip(b' \t')
    if FUZIX_LOGIN.search(plain):
        return 'fuzix_login'
    if CPM_PROMPT.search(plain):
        return 'cpm_prompt'
    if b'KX1:READY' in plain or b'KX2:HELLO:' in plain:
        return 'kx_receiver'
    if b'nano-Z80 monitor' in plain or b'nano-z80 monitor' in plain:
        return 'monitor'
    if b'FUZIX' in plain.upper():
        return 'fuzix_text'
    return 'unknown'


def key_to_bytes(key: str, *, backspace: str = 'del') -> bytes | None:
    """Map one msvcrt character to transmitted bytes. None means local exit."""
    if key == '\x1d':  # Ctrl+]
        return None
    if key in ('\r', '\n'):
        return b'\r'
    if key == '\x08':
        return b'\x7f' if backspace == 'del' else b'\x08'
    return key.encode('latin-1', 'replace')


def enable_vt_win() -> bool:
    if os.name != 'nt':
        return True
    try:
        import ctypes
        k32 = ctypes.windll.kernel32
        stdout = k32.GetStdHandle(-11)
        mode = ctypes.c_uint32()
        if not k32.GetConsoleMode(stdout, ctypes.byref(mode)):
            return False
        return bool(k32.SetConsoleMode(stdout, mode.value | 0x0004))
    except Exception:
        return False


def choose_log(path: str | None, *, enabled: bool) -> Path | None:
    if not enabled:
        return None
    if path:
        p = Path(path).expanduser()
    else:
        stamp = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        p = Path(__file__).resolve().parent / 'logs' / ('COM25_%s.binlog' % stamp)
    p.parent.mkdir(parents=True, exist_ok=True)
    if p.exists():
        raise FileExistsError('Log file already exists; refusing overwrite: ' + str(p))
    return p


def run(args: argparse.Namespace) -> int:
    if os.name != 'nt':
        print('Interactive keyboard mode is designed for Windows; use MobaXterm on Windows.', file=sys.stderr)
        return 2
    try:
        import msvcrt
        import serial
    except ImportError:
        print('Missing pyserial. Install once: py -3 -m pip install pyserial', file=sys.stderr)
        return 2

    enable_vt_win()
    logpath = choose_log(args.logfile, enabled=not args.no_log)
    print('nano-Z80 / FUZIX SERIAL TERMINAL | %s @ %d 8N1' % (args.port, args.baud))
    print('Terminal only: no Flash or SD programming. Ctrl+] exits locally.')
    print('Close MobaXterm, KonSol Commander and all other %s users first.' % args.port)
    print('Press Enter to show a waiting shell prompt. For CP/Mish A>, type FUZIX.')
    print('Serial FUZIX tty5 may have no getty enabled; if blank, check HDMI/SD image.')
    if logpath:
        print('Received bytes log (never uploaded to GitHub): ' + str(logpath))
    print('-' * 68)
    sys.stdout.flush()

    try:
        port = serial.Serial(args.port, args.baud, timeout=0.03,
                             bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                             stopbits=serial.STOPBITS_ONE, xonxoff=False,
                             rtscts=False, dsrdtr=False)
    except Exception as exc:
        print('Cannot open %s: %s' % (args.port, exc), file=sys.stderr)
        return 2

    tail = bytearray()
    prev_class = 'unknown'
    log = None
    try:
        if logpath:
            log = logpath.open('xb')
        with port:
            while True:
                rx = port.read(port.in_waiting or 1)
                if rx:
                    sys.stdout.buffer.write(rx)
                    sys.stdout.buffer.flush()
                    if log:
                        log.write(rx)
                        log.flush()
                    tail.extend(rx)
                    if len(tail) > 8192:
                        del tail[:-4096]
                    kind = classify_tail(bytes(tail))
                    if kind != prev_class and kind in ('fuzix_login', 'cpm_prompt', 'kx_receiver'):
                        # Append a diagnostic to stderr, without emitting any serial bytes.
                        descriptions = {
                            'fuzix_login': 'FUZIX login prompt observed on UART',
                            'cpm_prompt': 'CP/Mish prompt observed on UART',
                            'kx_receiver': 'KX22 receiver active; type Q to return to BASIC',
                        }
                        print('\n[HOST: %s]' % descriptions[kind], file=sys.stderr)
                    prev_class = kind
                if msvcrt.kbhit():
                    char = msvcrt.getwch()
                    if char in ('\x00', '\xe0'):
                        special = msvcrt.getwch()
                        tx = KEYMAP.get(special, b'')
                    else:
                        tx = key_to_bytes(char, backspace=args.backspace)
                        if tx is None:
                            print('\n[HOST: disconnected locally; no device reset]', file=sys.stderr)
                            break
                    if tx:
                        port.write(tx)
    except KeyboardInterrupt:
        print('\n[HOST: interrupted locally; no device reset]', file=sys.stderr)
    except Exception as exc:
        print('\nSerial failure: %s' % exc, file=sys.stderr)
        return 1
    finally:
        if log:
            log.close()
    return 0


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description='nano-Z80 COM25 FUZIX/CPMish Windows serial terminal')
    p.add_argument('--port', default=DEFAULT_PORT)
    p.add_argument('--baud', type=int, default=BAUDRATE)
    p.add_argument('--backspace', choices=['del', 'bs'], default='del')
    p.add_argument('--no-log', action='store_true', help='disable RX byte log')
    p.add_argument('--logfile', help='path for new RX log (must not exist)')
    args = p.parse_args(argv)
    if not 1200 <= args.baud <= 1000000:
        p.error('unsupported baud rate')
    return run(args)


if __name__ == '__main__':
    raise SystemExit(main())