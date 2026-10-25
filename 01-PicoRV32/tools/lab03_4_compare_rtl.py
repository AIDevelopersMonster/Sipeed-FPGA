#!/usr/bin/env python3
"""LAB-03.4 v0.2: compare board and RTL accepted-bus FETCH/LED trace cores.

The compared objects are accepted bus events, not instruction retirements.
Only stable command-dispatch core (from PC=0x048 to final LED write) is
compared, because the UART polling prefix depends on sampling phase.
Requires lab03_4_analyze.py v0.1 beside this file.
Does not open a serial port, modify ROM, or program FPGA.
"""
from __future__ import annotations

import argparse
import csv
import hashlib
import itertools
import json
import re
import sys
from pathlib import Path

import lab03_4_analyze as audit

ANCHOR = 0x048
RTL_PASS = 'LAB03_2_UART_TRACE_RTL_PASS'


def hash_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def format_event(sig) -> str:
    if sig is None:
        return 'MISSING'
    kind, addr, word = sig
    tag = 'FETCH' if kind == 1 else 'LED_WRITE' if kind == 2 else f'KIND_{kind}'
    return f'{tag} addr=0x{addr:08X} value=0x{word:08X}'


def verify_expected_hash(bytes_value: bytes, expected: str | None, source: str) -> None:
    if expected and hash_bytes(bytes_value).lower() != expected.lower():
        raise audit.EvidenceError(f'{source} SHA256 unexpected: {hash_bytes(bytes_value)} vs {expected}')


def normalize_rtl(events: list[audit.Event]):
    anchors = [i for i, e in enumerate(events) if e.kind == 1 and e.addr == ANCHOR]
    if len(anchors) != 1:
        raise audit.EvidenceError(f'RTL: expected exactly one dispatch anchor 0x{ANCHOR:03X}, found {len(anchors)}')
    cut = anchors[0]
    prefix = events[:cut]
    if prefix and not audit.matches_poll_pattern(prefix):
        raise audit.EvidenceError('RTL prefix does not follow the expected UART polling PC cycle')
    return prefix, events[cut:]


def compare(evidence: Path, rom_file: Path, rtl_file: Path, rtl_log: Path,
            command: int = 4, expected_rom_sha256: str | None = None,
            expected_bitstream_sha256: str | None = None) -> dict:
    if command != 4:
        raise audit.EvidenceError('v0.2 comparison contract is defined for command 4 only')
    rom_bytes = rom_file.read_bytes()
    verify_expected_hash(rom_bytes, expected_rom_sha256, 'Reference LAB-03 ROM')
    result = audit.analyze(audit.source_reader(evidence), rom_override=rom_bytes, rom_label=str(rom_file))
    if result['rom_mismatches']:
        raise audit.EvidenceError(f"Board evidence differs from reference ROM at {len(result['rom_mismatches'])} FETCH records")
    campaign_bitstream_hash = result['manifest'].get('bitstream', {}).get('sha256')
    if expected_bitstream_sha256 and str(campaign_bitstream_hash).lower() != expected_bitstream_sha256.lower():
        raise audit.EvidenceError('Campaign bitstream hash differs from the expected bitstream SHA256')
    command_info = result['groups'].get(str(command))
    if not command_info:
        raise audit.EvidenceError('Command 4 is missing from board evidence')

    log = rtl_log.read_text(encoding='utf-8-sig', errors='replace')
    if not re.search(r'(?m)^LAB03_2_UART_TRACE_RTL_PASS:', log):
        raise audit.EvidenceError(f'RTL simulation PASS marker not present in {rtl_log}')
    rtl_bytes = rtl_file.read_bytes()
    header_word, command_word, rtl_events = audit.parse_dump(rtl_bytes, command, str(rtl_file))
    rom = result['rom_words']
    rtl_fetch = [e for e in rtl_events if e.kind == 1]
    rtl_rom_mismatches = []
    for e in rtl_fetch:
        word = rom[e.addr // 4] if e.addr // 4 < len(rom) else None
        if word != e.value:
            rtl_rom_mismatches.append(f'0x{e.addr:03X}: RTL 0x{e.value:08X}, ROM {word}')
    if rtl_rom_mismatches:
        raise audit.EvidenceError('RTL fetch words not equal to provided ROM: ' + ', '.join(rtl_rom_mismatches[:5]))
    rtl_prefix, rtl_core = normalize_rtl(rtl_events)
    hw_core = [tuple(e) for e in command_info['core_events']]
    rtl_core_signatures = [e.signature for e in rtl_core]
    matching = (hw_core == rtl_core_signatures)
    differing = []
    for n, (board, model) in enumerate(itertools.zip_longest(hw_core, rtl_core_signatures), 1):
        if board != model:
            differing.append({'core_index': n, 'board': board, 'rtl': model})
    if command_info['stable_core_fetches'] + 1 != len(hw_core):
        raise audit.EvidenceError('Board stable core does not end with exactly one LED write')
    return {
        'command': command,
        'pass': matching,
        'board_runs': command_info['runs'],
        'board_total_runs': len(result['runs']),
        'board_core_events': len(hw_core),
        'board_core_fetches': command_info['stable_core_fetches'],
        'rtl_core_events': len(rtl_core),
        'rtl_core_fetches': sum(e.kind == 1 for e in rtl_core),
        'rtl_total_events': len(rtl_events),
        'rtl_total_fetches': len(rtl_fetch),
        'rtl_poll_prefix_fetches': len(rtl_prefix),
        'board_poll_prefix_fetches_by_run': command_info['poll_prefix_fetches_by_run'],
        'first_diff': differing[0] if differing else None,
        'diffs': differing,
        'board_core': hw_core,
        'rtl_core': rtl_core_signatures,
        'board_rom_sha256': hash_bytes(rom_bytes),
        'bitstream_sha256_declared': campaign_bitstream_hash,
        'rtl_dump_sha256': hash_bytes(rtl_bytes),
        'rtl_log_sha256': hash_bytes(rtl_log.read_bytes()),
        'source_evidence': str(evidence),
        'rom_file': str(rom_file),
        'rtl_file': str(rtl_file),
        'rtl_log': str(rtl_log),
        'scope': 'accepted bus FETCH and LED_WRITE signatures, normalized from PC=0x048; NOT cycles or retired instructions',
    }


def write_report(result: dict, out: Path):
    out.mkdir(parents=True, exist_ok=True)
    public = {k: v for k, v in result.items() if k not in ('board_core', 'rtl_core', 'diffs')}
    (out / 'summary.json').write_text(json.dumps(public, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    with (out / 'core_comparison.csv').open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['core_index', 'board_kind', 'board_addr', 'board_value', 'rtl_kind', 'rtl_addr', 'rtl_value', 'match'])
        for n, (board, rtl) in enumerate(itertools.zip_longest(result['board_core'], result['rtl_core']), 1):
            def unpack(x):
                if x is None: return ['', '', '']
                return [x[0], f'0x{x[1]:08X}', f'0x{x[2]:08X}']
            writer.writerow([n, *unpack(board), *unpack(rtl), 'PASS' if board == rtl else 'MISMATCH'])
    lines = [
        '# LAB-03.4 v0.2 — Board / RTL accepted-bus event comparison',
        '',
        '**Result:** `' + ('RTL_BUS_TRACE_CORE_EQUIVALENCE_PASS' if result['pass'] else 'RTL_BUS_TRACE_CORE_MISMATCH') + '`',
        '',
        '| Field | Value |', '|---|---|',
        f"| Command | {result['command']} |",
        f"| Board campaign | {result['board_total_runs']} runs; command 4: {result['board_runs']} runs |",
        f"| Board normalized core | {result['board_core_fetches']} FETCH, {result['board_core_events']} events |",
        f"| RTL normalized core | {result['rtl_core_fetches']} FETCH, {result['rtl_core_events']} events |",
        f"| RTL polling prefix | {result['rtl_poll_prefix_fetches']} FETCH |",
        f"| RTL raw capture | {result['rtl_total_events']} events, SHA256 `{result['rtl_dump_sha256']}` |",
        f"| Reference ROM SHA256 | `{result['board_rom_sha256']}` |",
        f"| Declared board bitstream SHA256 | `{result['bitstream_sha256_declared']}` |",
        '',
        'Normalization excludes only the variable leading poll FETCH segment, and compares every event signature from the single PC `0x048` fetch to the final accepted LED write, including look-ahead FETCH events.',
        'Cycle offsets and absolute indices are intentionally not compared. Accepted bus FETCH does not prove ISA retirement.',
        '',
    ]
    if result['first_diff']:
        d = result['first_diff']
        lines += ['## First mismatch', '', f"- Core event: {d['core_index']}", f"- Board: `{format_event(d['board'])}`", f"- RTL: `{format_event(d['rtl'])}`", '', 'See `core_comparison.csv` for the complete diff.', '']
    else:
        lines += ['## Match boundary', '', 'All normalized command-4 bus event signatures match. This does not establish full architectural instruction retirement, all-input equivalence, or cycle-level timing equivalence.', '']
    lines += [
        '## Reproducibility and provenance', '',
        f"- Board evidence: `{result['source_evidence']}`",
        f"- ROM: `{result['rom_file']}`",
        f"- RTL raw: `{result['rtl_file']}`",
        f"- RTL testbench log: `{result['rtl_log']}`",
        '- The RTL testbench PASS marker is checked. The wrapper additionally validates unchanged local ROM/ROM-Verilog SHA256 before and after simulation.',
        '- No FPGA SRAM readback or mathematical proof of compiled bitstream ↔ RTL correspondence was performed.',
    ]
    (out / 'report.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main(argv=None):
    ap = argparse.ArgumentParser(description='LAB-03.4 v0.2: normalize and compare board/RTL command-4 accepted-bus traces.')
    ap.add_argument('--evidence', type=Path, required=True)
    ap.add_argument('--rom', type=Path, required=True)
    ap.add_argument('--rtl', type=Path, required=True)
    ap.add_argument('--rtl-log', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--command', type=int, default=4)
    ap.add_argument('--expect-rom-sha256', default=None)
    ap.add_argument('--expect-bitstream-sha256', default=None)
    args = ap.parse_args(argv)
    try:
        result = compare(args.evidence, args.rom, args.rtl, args.rtl_log,
                         args.command, args.expect_rom_sha256, args.expect_bitstream_sha256)
        write_report(result, args.out)
        label = 'PASS' if result['pass'] else 'MISMATCH'
        print(f'LAB03_4_RTL_BUS_CORE_{label}: command={args.command}, board_CORE_FETCH={result["board_core_fetches"]}, '
              f'rtl_CORE_FETCH={result["rtl_core_fetches"]}, board_runs={result["board_runs"]}, '
              f'rtl_poll_prefix={result["rtl_poll_prefix_fetches"]}')
        if result['first_diff']:
            d = result['first_diff']
            print(f'FIRST_DIFF core_index={d["core_index"]}: board={format_event(d["board"])}; rtl={format_event(d["rtl"])}')
        print(f'LAB03_4_REPORT: {args.out.resolve() / "report.md"}')
        return 0 if result['pass'] else 2
    except (audit.EvidenceError, FileNotFoundError, ValueError, OSError) as exc:
        print(f'LAB03_4_COMPARISON_BLOCKED: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
