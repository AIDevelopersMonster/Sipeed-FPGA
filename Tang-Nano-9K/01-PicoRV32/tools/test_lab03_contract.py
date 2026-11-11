#!/usr/bin/env python3
"""Independent LAB-03.1 source/ROM packaging preflight (NOT RTL simulation)."""
from __future__ import annotations
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = ROOT / 'rtl' / 'lab03_trace_capture.v'
tb_unit = ROOT / 'tests' / 'tb_lab03_trace_capture.v'
tb_soc = ROOT / 'tests' / 'tb_lab03_soc_trace.v'
for f in (source, tb_unit, tb_soc):
    if not f.is_file() or f.stat().st_size < 1000:
        raise SystemExit(f'LAB03_PREFLIGHT_FAIL missing/incomplete: {f}')
s = source.read_text(encoding='utf-8')
checks = {
    'accepted bus only': 'mem_valid && mem_ready' in s,
    'fetch separately identified': 'fetch_accept' in s,
    'LED address exact': "32'h2000_0000" in s,
    'truncation explicit': 'truncated' in s,
    'overlapping command explicit': 'overlap' in s,
    'timestamp wrap explicit': 'timestamp_wrapped' in s,
    'read interface': 'rd_valid' in s,
    'no PicoRV32 patch': 'module lab03_trace_capture' in s,
}
for name, ok in checks.items():
    if not ok:
        raise SystemExit(f'LAB03_PREFLIGHT_FAIL: {name}')
rom = (ROOT / 'firmware' / 'boot.hex').read_text(encoding='ascii').splitlines()
assert len(rom) == 256 and all(len(w)==8 for w in rom), 'Unexpected LAB-02 ROM shape'
print('LAB03_1_SOURCE_PREFLIGHT_PASS: source, TBs, 1 KiB LAB-02 ROM; NOT RTL/PNR/BOARD')
