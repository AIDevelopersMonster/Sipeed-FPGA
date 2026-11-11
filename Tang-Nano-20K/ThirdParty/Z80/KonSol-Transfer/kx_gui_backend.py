"""Thin, safe GUI adapter for the exact unmodified KonSol Transfer KX1 core.

This module never writes microSD or FPGA flash. It does not assume KX1
supports listing, renaming or deleting remote files.
"""
from __future__ import annotations

import hashlib
import os
from pathlib import Path
import re
import sys
import time
from typing import Any

import konsol_transfer as kx

HERE = Path(__file__).resolve().parent
KX1_SIBLING = HERE.parent / 'KonSol_Transfer_KX1_v0.1'
CORE = HERE / 'konsol_transfer.py'


def python_cli() -> str:
    """Use console Python for the piped child even when GUI starts via pythonw."""
    exe = Path(sys.executable)
    if exe.name.lower() == 'pythonw.exe':
        return str(exe.with_name('python.exe'))
    return str(exe)


def state_path() -> Path:
    """Reuse proven KX1 history when GUI is extracted next to KX1."""
    sibling = KX1_SIBLING / 'KXFER_STATE.json'
    if KX1_SIBLING.is_dir():
        return sibling
    return HERE / 'KXFER_STATE.json'


def known_files(path: Path | None = None) -> list[dict[str, Any]]:
    state = kx._read_state(path or state_path())
    rows = []
    for remote, item in state.items():
        try:
            name = kx.normalized_name(remote)
        except kx.TransferError:
            continue
        if not isinstance(item, dict):
            continue
        size = item.get('size')
        if not isinstance(size, int) or size < 0:
            continue
        rows.append({'name': name, 'size': size, 'sha256': item.get('sha256', '')})
    return sorted(rows, key=lambda row: (row['name'][0], row['name'][2:]))


def forget_known_file(remote: str, path: Path | None = None) -> bool:
    """Forget one Windows-side transfer record, never modify the Z80 disk.

    The resulting manifest retains all other entries and is replaced atomically.
    Deleting metadata also loses KX1's exact-length/SHA knowledge for this name.
    """
    name = kx.normalized_name(remote)
    statefile = path if path is not None else state_path()
    state = kx._read_state(statefile)
    if name not in state:
        return False
    del state[name]
    kx._save_state(statefile, state)
    return True


def build_send_command(port: str, local: Path | str, remote: str,
                       manifest: Path | None = None) -> list[str]:
    remote = kx.normalized_name(remote)
    src = Path(local).resolve()
    if not src.is_file():
        raise kx.TransferError(f'Файл Windows не найден: {src}')
    if src.stat().st_size > kx.MAX_SIZE:
        raise kx.TransferError('Лимит KX1: 512 КиБ на файл')
    return [python_cli(), '-u', str(CORE), '--port', port.strip().upper(),
            '--state', str(manifest or state_path()), 'send', str(src), remote]


def build_get_command(port: str, remote: str, local: Path | str, *,
                      mode: str = 'auto', exact_length: int | None = None,
                      manifest: Path | None = None) -> list[str]:
    remote = kx.normalized_name(remote)
    dst = Path(local).resolve()
    if dst.exists():
        raise kx.TransferError(f'Файл Windows уже существует (без перезаписи): {dst}')
    if mode not in ('auto', 'full', 'exact'):
        raise kx.TransferError('Неизвестный режим длины')
    args = [python_cli(), '-u', str(CORE), '--port', port.strip().upper(),
            '--state', str(manifest or state_path()), 'get', remote, str(dst)]
    if mode == 'full':
        args.append('--full')
    if mode == 'exact':
        if exact_length is None or not isinstance(exact_length, int) or exact_length < 0:
            raise kx.TransferError('Нужна точная длина в байтах (целое число >= 0)')
        args += ['--length', str(exact_length)]
    return args


def filename_83(name: str) -> str | None:
    raw = name.upper()
    if re.fullmatch(r'[A-Z0-9_\-]{1,8}\.[A-Z0-9_\-]{1,3}', raw):
        return raw
    return None


def _read_prompt(port, seconds: float) -> str:
    """Read the response to one EMPTY command, never issue an unsafe command."""
    deadline = time.monotonic() + seconds
    buf = bytearray()
    last_rx = time.monotonic()
    while time.monotonic() < deadline:
        block = port.read(100)
        if block:
            buf.extend(block)
            last_rx = time.monotonic()
            if len(buf) > 10000:
                del buf[:5000]
        text = buf.decode('latin1', errors='replace')
        if 'KX1:READY' in text:
            return 'READY'
        if re.search(r'(?:^|[\r\n])A>\s*$', text):
            return 'A'
        if re.search(r'(?:^|[\r\n])B>\s*$', text):
            return 'B'
        if text.rstrip().endswith('>') and time.monotonic() - last_rx > 0.35:
            return 'BASIC'
    return 'UNKNOWN'


def rename_known_file(old: str, new: str, path: Path | None = None) -> bool:
    """Preserve the exact-length transfer metadata after a successful board rename."""
    old, new = kx.normalized_name(old), kx.normalized_name(new)
    statefile = path if path is not None else state_path()
    state = kx._read_state(statefile)
    if old not in state:
        return False
    state[new] = state.pop(old)
    kx._save_state(statefile, state)
    return True


def boot_receiver(port_name: str, *, port=None, probe_seconds: float = 4) -> str:
    """Start installed KX22 from CP/M, or recognize one already running.

    Safe for board storage: it never installs, flashes, or overwrites files.
    """
    from kx2_client import Manager
    own = port is None
    if own:
        port = kx._open_serial(port_name)
    try:
        protocol = kx.Protocol(port, pace_ms=1.0, timeout=25)
        protocol.putline('')
        mode = _read_prompt(port, probe_seconds)
        if mode == 'READY':
            Manager(port).probe()
            return 'KX22 уже запущен на FPGA'
        if mode == 'B':
            protocol.putline('A:')
            mode = _read_prompt(port, probe_seconds)
        if mode == 'A':
            protocol.putline('BBCBASIC B:KX22')
            protocol.expect('KX1:READY', timeout=35)
            Manager(port).probe()
            return 'KX22 запущен с диска B: на FPGA'
        if mode == 'BASIC':
            raise kx.TransferError('Открыт другой экран BASIC. Выйдите через *BYE и запустите KX22.')
        raise kx.TransferError('Нет приглашения A>/B> или KX22:READY. Проверьте COM25 и состояние платы.')
    finally:
        if own:
            port.close()