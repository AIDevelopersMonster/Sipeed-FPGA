"""KonSol KX2 v0.2.1 management transport.

KX1's proven send/get code remains unmodified. Unlike KX1.Protocol.status,
KX2 status MUST recognize both KX1: and KX2: prefixed responses.
Every operation performs a non-destructive V capability probe first.
"""
from __future__ import annotations

import time
import re

import konsol_transfer as kx

HELLO = 'KX2:HELLO:0.2.1:LDR'
PROTECTED = frozenset({'KXFER.TMP', 'KXFER.BBC', 'KX2FER.BBC', 'KX21.BBC', 'KX22.BBC'})


def safe_file(raw: str) -> str:
    name = kx.normalized_name(raw)
    if name[2:] in PROTECTED:
        raise kx.TransferError('Protected protocol receiver/staging file: ' + name)
    return name


class Manager:
    """One short-lived COM session, never changes Flash or host files."""

    def __init__(self, port, *, pace_ms: float = 1.0, timeout: float = 20):
        self.proto = kx.Protocol(port, pace_ms=pace_ms, timeout=timeout)
        self.timeout = timeout
        self.probed = False

    def _status(self, *, timeout: float | None = None) -> str:
        """Return one serial status, accepting KX1 and KX2 (unlike old KX1 status())."""
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        while time.monotonic() < deadline:
            line = self.proto._rawline(deadline)
            # UART echoes, '?' prompt prefixes, CRLF, and BASIC output are legal.
            kx2_index = line.rfind('KX2:')
            kx1_index = line.rfind('KX1:')
            start = max(kx1_index, kx2_index)
            if start >= 0:
                return line[start:].strip()
        raise kx.TransferError('KX2 timeout waiting for receiver status')

    def _await(self, prefix: str, *, timeout: float | None = None) -> str:
        deadline = time.monotonic() + (self.timeout if timeout is None else timeout)
        while time.monotonic() < deadline:
            status = self._status(timeout=max(0.01, deadline-time.monotonic()))
            if status.startswith('KX2:ERR:'):
                raise kx.TransferError('KX2 receiver: ' + status)
            if status.startswith('KX1:ERR:'):
                raise kx.TransferError('KX1 receiver rejected command: ' + status)
            if status.startswith(prefix):
                return status
            if status in ('KX1:READY', 'KX2:READY'):
                continue
            raise kx.TransferError(f'Expected {prefix!r}, received {status!r}')
        raise kx.TransferError('KX2 timeout waiting for ' + prefix)

    def probe(self, *, timeout: float = 8) -> str:
        """The literal V probe proves this receiver has the repaired dispatcher."""
        if self.probed:
            return HELLO
        self.proto.putline('V')
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            msg = self._status(timeout=max(.01, deadline-time.monotonic()))
            if msg == HELLO:
                self.probed = True
                return msg
            if msg == 'KX1:ERR:MODE':
                raise kx.TransferError(
                    'FPGA reports KX1:ERR:MODE. The active receiver is KX1 or '
                    'the defective KX2 v0.2.0. Exit with Q / *BYE and install/run B:KX22.BBC.'
                )
            if msg.startswith(('KX1:ERR:', 'KX2:ERR:')):
                raise kx.TransferError('Receiver rejected KX2 probe: ' + msg)
            if msg in ('KX1:READY', 'KX2:READY'):
                continue
            if msg.startswith('KX2:HELLO:'):
                raise kx.TransferError('Unsupported KX2 receiver version: ' + msg)
            raise kx.TransferError('Unexpected response to V probe: ' + msg)
        raise kx.TransferError('No KX2 version reply. Is B:KX22.BBC running on FPGA?')

    def _command(self, command: str, prompt: str, argument: str) -> None:
        self.proto.putline(command)
        self._await(prompt)
        self.proto.putline(argument)

    def list_raw(self, drive: str) -> str:
        drive = drive.strip().upper().rstrip(':')
        if drive not in ('A', 'B'):
            raise kx.TransferError('Only A: and B: supported')
        self.probe()
        self._command('L', 'KX2:DRIVE', drive)
        begin = self._await('KX2:LIST:BEGIN:')
        if begin != 'KX2:LIST:BEGIN:' + drive:
            raise kx.TransferError('KX2 directory begin marker mismatch: ' + begin)
        output = []
        deadline = time.monotonic() + 40
        while time.monotonic() < deadline:
            line = self.proto._rawline(deadline)
            end_index = line.rfind('KX2:LIST:END:')
            if end_index >= 0:
                if line[end_index:].strip() != 'KX2:LIST:END:' + drive:
                    raise kx.TransferError('KX2 directory end marker mismatch: ' + line)
                result = '\n'.join(output).strip()
                if re.search(r'(?i)(bad command|unknown command|syntax error|invalid drive|bad filename|not supported)', result):
                    raise kx.TransferError('OSCLI DIR not supported / failed: ' + result[-200:])
                return result
            if 'KX2:ERR:' in line or 'KX1:ERR:' in line:
                raise kx.TransferError('Receiver directory error: ' + line)
            output.append(line)
            if len(output) > 5000:
                raise kx.TransferError('Directory output exceeds 5000 lines')
        raise kx.TransferError('Directory end marker not received. OSCLI DIR may be unsupported.')

    def delete(self, remote: str, *, confirmed: bool = False) -> None:
        remote = safe_file(remote)
        if not confirmed:
            raise kx.TransferError('Deletion requires explicit UI confirmation')
        self.probe()
        self._command('D', 'KX2:NAME', remote)
        self._await('KX2:CONFIRM')
        self.proto.putline('DELETE ' + remote)
        done = self._await('KX2:DONE:DELETE:')
        if done != 'KX2:DONE:DELETE:' + remote:
            raise kx.TransferError('Unexpected deletion confirmation: ' + done)

    def rename(self, old: str, new: str, *, confirmed: bool = False) -> None:
        old = safe_file(old)
        new = safe_file(new)
        if old == new or old[:2] != new[:2]:
            raise kx.TransferError('Rename must change the name within the same disk')
        if not confirmed:
            raise kx.TransferError('Rename requires explicit UI confirmation')
        self.probe()
        self._command('R', 'KX2:SOURCE', old)
        self._await('KX2:DEST')
        self.proto.putline(new)
        self._await('KX2:CONFIRM')
        self.proto.putline('RENAME ' + old + ' ' + new)
        done = self._await('KX2:DONE:RENAME:')
        if done != 'KX2:DONE:RENAME:' + new:
            raise kx.TransferError('Unexpected rename confirmation: ' + done)
