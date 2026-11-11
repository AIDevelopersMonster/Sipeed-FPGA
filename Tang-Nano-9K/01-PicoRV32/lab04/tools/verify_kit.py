#!/usr/bin/env python3
"""Read-only package integrity check for LAB-04 source and generated ROM.

No network/Gowin/COM/HDMI; excludes generated build/, backups/ and __pycache__/.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUMS = ROOT / 'SHA256SUMS.txt'


def listed_files() -> set[str]:
    return {
        p.relative_to(ROOT).as_posix()
        for p in ROOT.rglob('*')
        if p.is_file()
        and not any(part in ('build', 'backups', '__pycache__', '.pytest_cache') for part in p.relative_to(ROOT).parts)
        and p != SUMS
        # Explicit pre-upgrade backups are not source artifacts. The installer
        # saves backups under build/, while prior manual hotfixes may have
        # left .bak_YYYYMMDD_HHMMSS files beside tests/SDC.
        and not re.search(r'\.bak(?:_|$)|\.before-full28-report\.bak$',p.name)
    }


def main() -> int:
    if not SUMS.exists():
        raise ValueError('Missing SHA256SUMS.txt')
    expected = {}
    for line in SUMS.read_text(encoding='utf-8').splitlines():
        if not line.strip():
            continue
        digest, sep, path = line.partition('  ')
        if not sep or not re.fullmatch('[0-9a-f]{64}', digest) or path in expected or not path:
            raise ValueError('Invalid checksum record: ' + line)
        expected[path] = digest
    present = listed_files()
    if present != set(expected):
        raise ValueError(f'File set mismatch, missing={set(expected)-present}, extra={present-set(expected)}')
    for name, expected_sha in expected.items():
        got = hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
        if got != expected_sha:
            raise ValueError(f'Checksum mismatch: {name}')
    meta = ROOT / 'firmware' / 'lab04_rom_meta.json'
    import json
    m = json.loads(meta.read_text(encoding='utf-8'))
    if not (0 < m['active_instructions'] <= 4096) or m['capacity_words'] != 4096:
        raise ValueError('Unexpected firmware size')
    h = hashlib.sha256((ROOT / 'firmware' / 'lab04_boot.hex').read_bytes()).hexdigest()
    if h != m['rom_sha256']:
        raise ValueError('Firmware metadata digest mismatch')
    print(f'LAB04_SOURCE_INTEGRITY_PASS: files={len(expected)}, ROM={m["active_instructions"]}/4096')
    print('LAB04_SCOPE: source bytes only; no RTL/PNR/STA/BOARD claim')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (OSError, KeyError, ValueError) as err:
        print('LAB04_SOURCE_INTEGRITY_FAIL:', err, file=sys.stderr)
        raise SystemExit(1)
