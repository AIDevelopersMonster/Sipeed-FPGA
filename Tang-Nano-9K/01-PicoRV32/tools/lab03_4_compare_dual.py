#!/usr/bin/env python3
"""LAB-03.4 v0.3: compare existing 0/4 board campaign with one RTL TB run.

Reuses the v0.1 board audit and v0.2 normalization without changing them.
Compares all (kind, address, word/value) signatures from PC=0x048 through the
final LED MMIO write; deliberately excludes phase-dependent poll prefix and
relative cycle numbers. Not an instruction-retirement or cycle proof.
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
import lab03_4_compare_rtl as old

ROM_SHA256 = '14b85bc20ce43cdf4ce09ef1db7a20af5677c1c728c64b71258f6c63ab5b8a3d'
FS_SHA256 = '62596847427f0258cb729a8b3c042ab7e0f39a8725990ba39a831b98c6554f13'


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def check_hash(data: bytes, expected: str | None, desc: str):
    digest = sha(data)
    if expected and digest.lower() != expected.lower():
        raise audit.EvidenceError(f'{desc}: SHA256 {digest} != expected {expected}')
    return digest


def require_log_markers(log: str):
    for marker in ('LAB03_2_UART_TRACE_RTL_PASS', 'LAB03_4_ZERO_UART_TRACE_RTL_PASS'):
        if not re.search(r'(?m)^' + re.escape(marker) + r':', log):
            raise audit.EvidenceError(f'Combined RTL testbench PASS marker absent: {marker}')


def compare_command(board_group: dict, words: list[int], rtl_bytes: bytes, cmd: int,
                    name: str) -> dict:
    head, cw, events = audit.parse_dump(rtl_bytes, cmd, name)
    prefix, core = old.normalize_rtl(events)
    rtl_fetches = [e for e in events if e.kind == 1]
    mismatches = []
    for e in rtl_fetches:
        rom_word = words[e.addr // 4] if e.addr // 4 < len(words) else None
        if rom_word != e.value:
            mismatches.append(f'PC=0x{e.addr:03X}: RTL=0x{e.value:08X}, ROM={rom_word}')
    if mismatches:
        raise audit.EvidenceError(f'Command {cmd}: RTL FETCH word not in reference ROM: ' + '; '.join(mismatches[:4]))
    board_core = [tuple(e) for e in board_group['core_events']]
    rtl_core = [e.signature for e in core]
    if not board_core or board_core[-1][0] != 2:
        raise audit.EvidenceError(f'Command {cmd}: incomplete board normalized core')
    if not rtl_core or rtl_core[-1][0] != 2:
        raise audit.EvidenceError(f'Command {cmd}: incomplete RTL normalized core')
    diffs = [
        {'index': n, 'board': b, 'rtl': r}
        for n, (b, r) in enumerate(itertools.zip_longest(board_core, rtl_core), 1)
        if b != r
    ]
    return {
        'command': cmd,
        'pass': not diffs,
        'board_runs': board_group['runs'],
        'board_core_events': len(board_core),
        'board_core_fetches': board_group['stable_core_fetches'],
        'rtl_core_events': len(rtl_core),
        'rtl_core_fetches': sum(e.kind == 1 for e in core),
        'rtl_raw_events': len(events),
        'rtl_raw_fetches': len(rtl_fetches),
        'rtl_poll_prefix_fetches': len(prefix),
        'board_poll_prefix_fetches_by_run': board_group['poll_prefix_fetches_by_run'],
        'rtl_dump_sha256': sha(rtl_bytes),
        'rtl_dump_path': name,
        'board_core': board_core,
        'rtl_core': rtl_core,
        'diffs': diffs,
        'first_diff': diffs[0] if diffs else None,
    }


def compare_dual(evidence: Path, rom_path: Path, rtl_0: Path, rtl_4: Path,
                 rtl_log: Path, expected_rom_sha256: str | None = ROM_SHA256,
                 expected_bitstream_sha256: str | None = FS_SHA256) -> dict:
    rom_raw = rom_path.read_bytes()
    rom_hash = check_hash(rom_raw, expected_rom_sha256, 'LAB-03 reference ROM')
    board = audit.analyze(audit.source_reader(evidence), rom_override=rom_raw,
                          rom_label=str(rom_path))
    if board['rom_mismatches']:
        raise audit.EvidenceError(f"Board FETCH vs provided ROM: {len(board['rom_mismatches'])} mismatches")
    declared_fs_sha = board['manifest'].get('bitstream', {}).get('sha256', '')
    if expected_bitstream_sha256 and declared_fs_sha.lower() != expected_bitstream_sha256.lower():
        raise audit.EvidenceError('Declared board campaign bitstream SHA256 differs from expected value')
    log_raw = rtl_log.read_bytes()
    require_log_markers(log_raw.decode('utf-8-sig', errors='replace'))
    outcomes = {}
    for command, src in ((0, rtl_0), (4, rtl_4)):
        grp = board['groups'].get(str(command))
        if not grp:
            raise audit.EvidenceError(f'Board campaign has no command {command}')
        outcomes[str(command)] = compare_command(grp, board['rom_words'], src.read_bytes(), command, str(src))
    return {
        'version': 'LAB03.4-v0.3',
        'pass': all(x['pass'] for x in outcomes.values()),
        'commands': outcomes,
        'board_campaign_total_runs': len(board['runs']),
        'board_total_fetch': board['total_fetches'],
        'board_rom_match': board['rom_matches'],
        'board_rom_sha256': rom_hash,
        'board_rom_path': str(rom_path),
        'board_evidence': str(evidence),
        'bitstream_sha256_declared': declared_fs_sha,
        'rtl_log': str(rtl_log),
        'rtl_log_sha256': sha(log_raw),
        'scope': 'Normalized accepted bus FETCH/LED_WRITE signatures, command 0 and 4, no cycle or retirement claim',
    }


def human(sig):
    return old.format_event(sig)


def write_report(result: dict, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    summary = {k: v for k, v in result.items() if k != 'commands'}
    summary['commands'] = {
        k: {field: val for field, val in c.items() if field not in ('board_core', 'rtl_core', 'diffs')}
        for k, c in result['commands'].items()
    }
    (out / 'summary.json').write_text(json.dumps(summary, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    with (out / 'core_comparison.csv').open('w', encoding='utf-8-sig', newline='') as fp:
        writer = csv.writer(fp)
        writer.writerow(['command','core_index','board_kind','board_addr','board_value','rtl_kind','rtl_addr','rtl_value','match'])
        for cmd, res in sorted(result['commands'].items(), key=lambda x:int(x[0])):
            for n, (board, rtl) in enumerate(itertools.zip_longest(res['board_core'],res['rtl_core']),1):
                def cells(e):
                    if e is None: return ('', '', '')
                    return (e[0], f'0x{e[1]:08X}', f'0x{e[2]:08X}')
                writer.writerow([cmd,n,*cells(board),*cells(rtl),'PASS' if board == rtl else 'MISMATCH'])
    lines = [
        '# LAB-03.4 v0.3 — Comparison of real board and RTL accepted-bus traces',
        '',
        f"**Result:** `{'RTL_BUS_TRACE_CORE_EQUIVALENCE_PASS' if result['pass'] else 'RTL_BUS_TRACE_CORE_MISMATCH'}`",
        '',
        '| Command | Board captures | Board core FETCH | RTL core FETCH | RTL poll FETCH | Result |',
        '|---|---:|---:|---:|---:|---|',
    ]
    for cmd, group in sorted(result['commands'].items(), key=lambda x:int(x[0])):
        lines.append(f"| {cmd} | {group['board_runs']} | {group['board_core_fetches']} | {group['rtl_core_fetches']} | {group['rtl_poll_prefix_fetches']} | {'PASS' if group['pass'] else 'MISMATCH'} |")
    lines.extend([
        '',
        f"- Evidence: `{result['board_evidence']}` ({result['board_campaign_total_runs']} captures, {result['board_total_fetch']} total FETCH).",
        f"- LAB-03 ROM: `{result['board_rom_path']}`, SHA256 `{result['board_rom_sha256']}`.",
        f"- Declared campaign bitstream SHA256: `{result['bitstream_sha256_declared']}`; FPGA SRAM not independently read back.",
        f"- RTL simulation stdout: `{result['rtl_log']}`, SHA256 `{result['rtl_log_sha256']}`.",
        '',
        '## Scope',
        '',
        'Checks sequence equality of every `(kind, addr, value)` event from the single FETCH at PC=0x048 through the final accepted LED MMIO write, against the six recorded board runs of each command.',
        'The varying UART polling prefix (addresses 0x038, 0x03C, 0x040, 0x044) is validated structurally but deliberately excluded from signature equality.',
        'Relative cycle counts are not compared. FETCH is an accepted instruction read, not architectural retirement; branch look-ahead events may appear.',
        'This is an observation-limited comparison for TWO input commands, not formal equivalence of CPU, arbitrary commands, timings, or the configuration bitstream.',
        '',
    ])
    for cmd, group in sorted(result['commands'].items(), key=lambda x:int(x[0])):
        if group['first_diff']:
            diff = group['first_diff']
            lines.extend([f'## Command {cmd}: first difference', '',
                f"- Core index: {diff['index']}",
                f"- FPGA: `{human(diff['board'])}`",
                f"- RTL: `{human(diff['rtl'])}`", ''])
    lines.extend([
        '## Reproducibility and unresolved provenance', '',
        'The original LAB-03.2 testbench is NOT modified: v0.3 generates an additive copy under ignored `build/` with an extra `C -> 0 -> T` sequence.',
        'The pre-existing `4 -> T -> T -> C -> 1 -> T` scenarios and their PASS marker are retained.',
        'The wrapper additionally runs the original UART decoder and records source SHA256 plus Git status.',
        'Git HEAD alone does not identify the board bitstream when the source working tree is dirty; no SRAM readback was performed.',
        '',
    ])
    (out / 'report.md').write_text('\n'.join(lines), encoding='utf-8')


def main(argv=None):
    ap=argparse.ArgumentParser(description='LAB-03.4 v0.3: board vs RTL comparison for both commands 0 and 4')
    ap.add_argument('--evidence', type=Path, required=True)
    ap.add_argument('--rom', type=Path, required=True)
    ap.add_argument('--rtl-0', type=Path, required=True)
    ap.add_argument('--rtl-4', type=Path, required=True)
    ap.add_argument('--rtl-log', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    ap.add_argument('--expect-rom-sha256', default=ROM_SHA256)
    ap.add_argument('--expect-bitstream-sha256', default=FS_SHA256)
    args=ap.parse_args(argv)
    try:
        result=compare_dual(args.evidence,args.rom,args.rtl_0,args.rtl_4,args.rtl_log,
                            args.expect_rom_sha256,args.expect_bitstream_sha256)
        write_report(result,args.out)
        for cmd, c in sorted(result['commands'].items(),key=lambda x:int(x[0])):
            label='PASS' if c['pass'] else 'MISMATCH'
            print(f'LAB03_4_V03_RTL_BUS_CORE_{label}: command={cmd}, board_CORE_FETCH={c["board_core_fetches"]}, '
                  f'rtl_CORE_FETCH={c["rtl_core_fetches"]}, board_runs={c["board_runs"]}, rtl_poll_prefix={c["rtl_poll_prefix_fetches"]}')
            if c['first_diff']:
                d=c['first_diff']
                print(f'FIRST_DIFF: command={cmd}, core_index={d["index"]}, board={human(d["board"])}, rtl={human(d["rtl"])}')
        print(f'LAB03_4_V03_REPORT: {(args.out / "report.md").resolve()}')
        if result['pass']:
            print('LAB03_4_V03_DUAL_COMMAND_RTL_BUS_CORE_EQUIVALENCE_PASS: commands 0 and 4; no retirement/cycle claim')
            return 0
        print('LAB03_4_V03_DUAL_COMMAND_RTL_BUS_CORE_MISMATCH: see core_comparison.csv', file=sys.stderr)
        return 2
    except (audit.EvidenceError, OSError, KeyError, ValueError) as exc:
        print(f'LAB03_4_V03_COMPARISON_BLOCKED: {exc}', file=sys.stderr)
        return 1


if __name__=='__main__':
    sys.exit(main())
