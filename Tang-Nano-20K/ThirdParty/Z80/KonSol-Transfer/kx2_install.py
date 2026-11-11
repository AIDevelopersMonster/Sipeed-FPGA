"""Install KonSol KX2 with full DIR *.* into NEW B:KX22.BBC (not KXFER/KX2FER).

Requires CP/Mish A>/B> prompt. No FPGA Flash, raw disk image or KX1 edits.
Refuses to overwrite an existing B:KX22.BBC.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import konsol_transfer as kx
from kx2_client import Manager

BASIC_SOURCE = Path(__file__).with_name('KX22.BAS')
BASIC_DEST = 'B:KX22.BBC'


def _basic_line(protocol, port, text, *, timeout=15):
    protocol.putline(text)
    state, output = kx._prompt(port, timeout)
    if state != 'BASIC':
        raise kx.TransferError(f'BBC BASIC lost its prompt while executing: {text[:45]!r}: {output[-180:]}')
    if re.search(r'\b(?:Bad|Mistake|Syntax error|No room|Too big)\b', output, re.I):
        raise kx.TransferError(f'BBC BASIC rejected {text[:45]!r}: {output[-180:]}')
    return output


def install(port_name: str, *, pace_ms: float = 1.0) -> None:
    numbered = BASIC_SOURCE.read_text('ascii').splitlines()
    if not numbered or any(len(line) > 240 for line in numbered):
        raise kx.TransferError('Missing BASIC source or a line exceeds safe 240 bytes')
    if not all(re.fullmatch(r'\d+\s+.+', line) for line in numbered):
        raise kx.TransferError('Malformed numbered BASIC source')
    print('NEW INSTALL: ' + BASIC_DEST + '. Preserving B:KXFER.BBC and B:KX2FER.BBC.')
    with kx._open_serial(port_name) as port:
        protocol = kx.Protocol(port, pace_ms=pace_ms, timeout=30)
        protocol.putline('')
        state, output = kx._prompt(port)
        if state != 'CPM':
            raise kx.TransferError('Need CP/Mish A> or B>. Exit KX1/KX2 with Q, then *BYE.')
        protocol.putline('BBCBASIC')
        state, output = kx._prompt(port, 25)
        if state != 'BASIC':
            raise kx.TransferError('BBC BASIC prompt not received')

        # Hardware-side existence check before first SAVE; never overwrite.
        _basic_line(protocol, port, 'X%=OPENIN("B:KX22.BBC")')
        output = _basic_line(protocol, port, 'PRINT "KX22:CHECK:";X%')
        match = re.search(r'KX22:CHECK:\s*(\d+)', output)
        if not match:
            raise kx.TransferError('Cannot determine whether B:KX22.BBC already exists; SAVE refused')
        if int(match.group(1)) != 0:
            _basic_line(protocol, port, 'CLOSE#X%')
            raise kx.TransferError('B:KX22.BBC already exists. Installer will NOT overwrite it.')

        _basic_line(protocol, port, 'NEW')
        for n, line in enumerate(numbered, 1):
            _basic_line(protocol, port, line)
            if n % 25 == 0 or n == len(numbered):
                print(f'BBC BASIC loaded {n}/{len(numbered)} lines')
        output = _basic_line(protocol, port, 'SAVE "B:KX22"', timeout=90)
        if re.search(r'\b(?:Error|No room|Directory full|Disk full|Bad name)\b', output, re.I):
            raise kx.TransferError('BBC BASIC SAVE failed: ' + output[-180:])
        protocol.putline('RUN')
        protocol.expect('KX1:READY', timeout=30)
        hello = Manager(port, pace_ms=pace_ms, timeout=20).probe(timeout=15)
        print('KX2 v0.2.1 receiver RUN; VERSION PROBE PASS:', hello)
        print('COM released. Board LIST still requires an actual DIR readback test.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Install new B:KX22.BBC without touching KX1 or the old KX2FER')
    parser.add_argument('--port', default='COM25')
    parser.add_argument('--pace-ms', type=float, default=1.0)
    parser.add_argument('--yes', action='store_true')
    args = parser.parse_args()
    if not 0 <= args.pace_ms <= 50:
        parser.error('--pace-ms must be between 0 and 50')
    if not args.yes or input('Type INSTALL_KX22 (writes NEW B:KX22.BBC): ').strip() != 'INSTALL_KX22':
        parser.error('Explicit --yes and typed confirmation are required')
    try:
        install(args.port, pace_ms=args.pace_ms)
    except kx.TransferError as e:
        parser.exit(2, 'KX22 INSTALL ERROR: ' + str(e) + '\n')
