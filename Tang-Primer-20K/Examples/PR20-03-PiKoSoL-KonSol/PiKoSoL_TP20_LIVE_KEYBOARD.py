#!/usr/bin/env python3
"""PiKoSoL TP20: live Windows keyboard -> UART (one byte per key).

Purpose:
    Replace the PC> input() line-buffered console without changing FPGA firmware.
    Printable keys, Backspace and Enter are transmitted immediately.  The FPGA
    remains responsible for local echo, line editing, command execution and HDMI.

Status:
    PC self-test is available; current TP20 FPGA behavior must be board-tested.

No FPGA programming, no flash writes, no GitHub mutations.
"""
from __future__ import annotations

import argparse
import sys
import time
from typing import Optional


# Common controls are intentionally a single byte (not VT100 escape sequences).
# The previous PiKoSoL PicoRV32 shell accepts 0x08 for Backspace and 0x10
# for one-line history recall.  The active TP20 firmware still needs to be
# checked before relying on its support for Ctrl+P.

def encode_key(first: str, extended: Optional[str] = None, *, up_recall: bool = False) -> bytes:
    """Convert a Windows getwch() event to exactly one UART byte or no bytes.

    Note: not all PiKoSoL versions support every control byte.  Never inject
    unsupported cursor-control ANSI sequences into the command interpreter.
    """
    if first in ('\x00', '\xe0'):
        # Windows extended key codes: H=up, P=down, K=left, M=right.
        if up_recall and extended == 'H':
            return b'\x10'  # Ctrl-P recall for the older PiKoSoL shell
        return b''
    if first in ('\r', '\n'):
        return b'\r'
    if first in ('\x08', '\x7f'):
        return b'\x08'
    if first == '\x10':
        return b'\x10'
    if first == '\t':
        return b''  # No unverified TAB protocol sent to the FPGA.
    if len(first) == 1 and 0x20 <= ord(first) <= 0x7e:
        return first.encode('ascii')
    return b''


def pc_output(data: bytes) -> bytes:
    """Filter private HDMI mode bytes from the optional PC serial mirror."""
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
    if not data:
        return
    clean = pc_output(data)
    if not clean:
        return
    # Do not let a console's encoding silently alter FPGA-provided ASCII.
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
    ap.add_argument('--hdmi-only', action='store_true', help='Read and discard incoming UART text; show output on FPGA HDMI only')
    ap.add_argument('--up-recall', action='store_true', help='Translate UP arrow into Ctrl-P, only for a firmware that supports recall')
    ap.add_argument('--selftest', action='store_true', help='Run mapping checks without serial port or FPGA')
    args = ap.parse_args()

    if args.selftest:
        return selftest()
    if args.baud <= 0:
        ap.error('baud rate must be positive')
    if not sys.platform.startswith('win'):
        print('LIVE MODE requires Windows console (msvcrt); --selftest works elsewhere.', file=sys.stderr)
        return 2

    try:
        import msvcrt  # Windows-only standard library, no keyboard hook.
    except ImportError as exc:
        print(f'Windows keyboard API not available: {exc}', file=sys.stderr)
        return 2
    try:
        import serial  # pyserial, same dependency as the former PiKoSoL console.
    except ImportError:
        print('Missing pyserial. Install once: python -m pip install pyserial', file=sys.stderr)
        return 2

    ser = None
    try:
        # Do not toggle DTR/RTS: avoid changing reset state of the USB-UART link.
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
        print('[PC] Keys are sent immediately.  PC does NOT echo typed keys.')
        print('[PC] Enter=CR, Backspace=BS, Ctrl-P=history (if FPGA supports), Esc=close PC client.')
        if args.up_recall:
            print('[PC] UP arrow -> Ctrl-P enabled (older PiKoSoL firmware).')
        if args.hdmi_only:
            print('[PC] HDMI-only mode: received UART output is hidden here.')
        print('[PC] Type HELP now; check whether each character appears on HDMI BEFORE Enter.')
        sys.stdout.flush()
        while True:
            # Keep RX drained regardless of whether we display the PC mirror.
            pending = ser.in_waiting
            if pending:
                chunk = ser.read(min(pending, 4096))
                if not args.hdmi_only:
                    print_bytes(chunk)

            while msvcrt.kbhit():
                first = msvcrt.getwch()
                if first in ('\x1b', '\x1d'):  # Esc or Ctrl+]
                    print('\n[PC] UART client closed. PiKoSoL remains running on FPGA.')
                    return 0
                ext = msvcrt.getwch() if first in ('\x00', '\xe0') else None
                payload = encode_key(first, ext, up_recall=args.up_recall)
                if payload:
                    # No input(), no PC> buffer, no PC->FPGA waiting for Enter.
                    ser.write(payload)
                    ser.flush()
            time.sleep(0.005)
    except KeyboardInterrupt:
        print('\n[PC] Interrupted. FPGA configuration untouched.')
        return 0
    except Exception as exc:
        print(f'\n[PC] UART/keyboard error: {exc}', file=sys.stderr)
        print('[PC] Close the old serial terminal; check COM port and baud rate.', file=sys.stderr)
        return 3
    finally:
        if ser is not None and ser.is_open:
            ser.close()


if __name__ == '__main__':
    raise SystemExit(main())
