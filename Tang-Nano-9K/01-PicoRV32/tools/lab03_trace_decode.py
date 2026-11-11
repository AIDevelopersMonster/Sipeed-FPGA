#!/usr/bin/env python3
"""LAB-03.2 T3 ASCII readout validator. Strict structure, count, ROM and final LED store.

A capture via T is a snapshot of acknowledged bus events, not an ISA retirement trace.
T3:<status 8hex>:<trigger 8hex>\n
E:<index 8hex>:<cycle_kind 8hex>:<address 8hex>:<value 8hex>\n
Z\n
No CRC in v0.1; therefore this does not claim undetectable corruption is excluded.
"""
from __future__ import annotations
import argparse
import json
import re
from pathlib import Path

HEADER = re.compile(r'^T3:([a-fA-F0-9]{8}):([a-fA-F0-9]{8})$')
EVENT = re.compile(r'^E:([a-fA-F0-9]{8}):([a-fA-F0-9]{8}):([a-fA-F0-9]{8}):([a-fA-F0-9]{8})$')


def decode(content: str, rom: list[int] | None = None, require_complete: bool = True) -> dict:
    rows = content.splitlines()
    if len(rows) < 2 or (match := HEADER.fullmatch(rows[0])) is None:
        raise ValueError('missing/malformed T3 header; expected T3:STATUS:COMMAND')
    if rows[-1] != 'Z':
        raise ValueError('missing final Z line')
    status, cmd = (int(x, 16) for x in match.groups())
    if status >> 24 != 3 or (status >> 16) & 255 != 128:
        raise ValueError(f'wrong trace protocol version/depth: {status:08x}')
    if status & (7 << 13):
        raise ValueError('reserved bits set in TRACE_STATUS')
    count = status & 255
    if count > 128 or len(rows) != count + 2:
        raise ValueError(f'snapshot count mismatch: header={count}, lines={len(rows)-2}')
    flags = {"done": bool(status & 0x100), "truncated": bool(status & 0x200),
             "overlap": bool(status & 0x400), "wrapped": bool(status & 0x800),
             "capturing": bool(status & 0x1000)}
    if require_complete and (not flags['done'] or any(flags[k] for k in ('truncated', 'overlap', 'wrapped', 'capturing'))):
        raise ValueError(f'incomplete capture: {flags}')
    if cmd >> 8 or (cmd and not (ord('0') <= cmd <= ord('6'))):
        raise ValueError(f'impossible trigger command: {cmd:08x}')
    events = []
    for idx, row in enumerate(rows[1:-1]):
        m = EVENT.fullmatch(row)
        if m is None:
            raise ValueError(f'bad event row {idx}: {row[:80]!r}')
        index, meta, addr, value = [int(x, 16) for x in m.groups()]
        if index != idx:
            raise ValueError(f'index not consecutive: expected {idx} got {index}')
        if meta >> 18:
            raise ValueError(f'unknown cycle_kind reserved bits: {meta:08x}')
        kind, cycle = (meta >> 16) & 3, meta & 65535
        if kind not in (1, 2):
            raise ValueError(f'event kind invalid: {kind}')
        if kind == 1:
            if addr >= 1024 or addr % 4:
                raise ValueError(f'fetch outside/alignment ROM at 0x{addr:08x}')
            if rom is not None and rom[addr // 4] != value:
                raise ValueError(f'ROM mismatch at index={index} 0x{addr:08x}: got {value:08x}, expected {rom[addr//4]:08x}')
        elif addr != 0x20000000:
            raise ValueError(f'LED write to wrong address 0x{addr:08x}')
        events.append(dict(index=index, cycle=cycle, kind=('FETCH' if kind == 1 else 'LED_WRITE'),
                           address=f'0x{addr:08x}', value=f'0x{value:08x}'))
        if idx and cycle < events[idx-1]['cycle'] and not flags['wrapped']:
            raise ValueError('relative timestamps decreased without wrap flag')
    if require_complete:
        if not events or events[-1]['kind'] != 'LED_WRITE':
            raise ValueError('snapshot did not finish in LED_WRITE')
        if sum(e['kind'] == 'LED_WRITE' for e in events) != 1:
            raise ValueError('multiple LED stores in one completed snapshot')
        if cmd:
            expected_mask = 0 if cmd == ord('0') else 1 << (cmd - ord('1'))
            if int(events[-1]['value'], 16) != expected_mask:
                raise ValueError(f'LED store differs from trigger: {events[-1]["value"]}, expected {expected_mask}')
    return dict(protocol='LAB03-T3-ASCII-v0.1', status=f'0x{status:08x}', command=chr(cmd) if cmd else None,
                count=count, flags=flags, events=events)


def read_rom(path: Path) -> list[int]:
    words = [int(line.strip(), 16) for line in path.read_text(encoding='ascii').splitlines() if line.strip()]
    if len(words) != 256:
        raise ValueError(f'ROM must contain 256 words, found {len(words)}')
    return words


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('file', type=Path, help='ASCII output of the T command, including Z line')
    parser.add_argument('--rom', type=Path, default=Path(__file__).resolve().parents[1] / 'firmware' / 'lab03_boot.hex')
    parser.add_argument('--expected-command', choices='0123456')
    parser.add_argument('--allow-incomplete', action='store_true')
    parser.add_argument('--json-out', type=Path)
    opts = parser.parse_args()
    trace = decode(opts.file.read_text(encoding='ascii'), read_rom(opts.rom), require_complete=not opts.allow_incomplete)
    if opts.expected_command is not None and trace['command'] != opts.expected_command:
        raise ValueError(f'wrong snapshot command {trace["command"]!r}, expected {opts.expected_command!r}')
    if opts.json_out:
        opts.json_out.parent.mkdir(parents=True, exist_ok=True)
        opts.json_out.write_text(json.dumps(trace, indent=2) + '\n', encoding='utf-8')
    fetches = sum(e['kind'] == 'FETCH' for e in trace['events'])
    print(f'LAB03_2_TRACE_DECODE_PASS: command={trace["command"]}, events={trace["count"]}, fetches={fetches}, '
          f'LED_WRITE={trace["events"][-1]["value"] if trace["events"] else "none"}, flags={trace["flags"]}')


if __name__ == '__main__':
    main()
