#!/usr/bin/env python3
"""LAB-03.4: offline, non-invasive PicoRV32 UART bus-fetch trace audit.

Checks archived evidence, decodes T3/E/Z, verifies per-PC observed words,
normalizes the variable polling prefix, and contrasts fetch words with a
separately provided ROM. A FETCH is NOT an instruction-retirement event.

Stdlib-only. Never accesses a COM port or an FPGA.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import io
import json
import re
import sys
import zipfile
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Callable, Optional

HEADER_RE = re.compile(r"T3:([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8})")
EVENT_RE = re.compile(r"E:([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8}):([0-9A-Fa-f]{8})")
POLL_CYCLE = (0x038, 0x03C, 0x040, 0x044)
MAX_EVENTS = 128


class EvidenceError(ValueError):
    pass


@dataclass(frozen=True)
class Event:
    index: int
    kind: int
    cycle: int
    addr: int
    value: int

    @property
    def signature(self):
        return (self.kind, self.addr, self.value)


@dataclass
class Run:
    index: int
    command: int
    source: str
    sha256: str
    header_word: int
    header_command_word: int
    events: list[Event]
    csv_row: dict
    poll_prefix: list[Event] | None = None
    common_core: list[Event] | None = None

    @property
    def fetches(self):
        return [e for e in self.events if e.kind == 1]


def _safe_relative(name: str) -> str:
    pos = PurePosixPath(name.replace('\\', '/'))
    if pos.is_absolute() or '..' in pos.parts or not pos.parts or pos.parts[0] != 'raw':
        raise EvidenceError(f"Untrusted raw_file path: {name}")
    return str(pos)


def source_reader(src: Path) -> Callable[[str], bytes]:
    if src.is_dir():
        def read(name: str):
            p = PurePosixPath(name)
            if p.is_absolute() or '..' in p.parts:
                raise EvidenceError('Unsafe evidence path')
            return (src / name).read_bytes()
        return read
    if zipfile.is_zipfile(src):
        archive = zipfile.ZipFile(src)
        if len({x.filename for x in archive.infolist()}) != len(archive.infolist()):
            raise EvidenceError('Duplicated ZIP member names')
        def read(name: str):
            p = PurePosixPath(name)
            if p.is_absolute() or '..' in p.parts:
                raise EvidenceError('Unsafe evidence path')
            return archive.read(name)
        return read
    raise EvidenceError(f'Evidence must be a directory or ZIP: {src}')


def parse_dump(data: bytes, command: int, source: str):
    try:
        lines = data.decode('utf-8-sig').splitlines()
    except UnicodeDecodeError as exc:
        raise EvidenceError(f'{source}: not UTF-8') from exc
    if len(lines) < 3 or lines[-1] != 'Z':
        raise EvidenceError(f'{source}: missing T3 header or Z terminator')
    hm = HEADER_RE.fullmatch(lines[0])
    if not hm:
        raise EvidenceError(f'{source}: malformed T3 header')
    word = int(hm.group(1), 16)
    command_word = int(hm.group(2), 16)
    if command_word != ord(str(command)):
        raise EvidenceError(f'{source}: header command differs from CSV: {command_word:08X} vs {command}')
    events = []
    for i, ln in enumerate(lines[1:-1]):
        em = EVENT_RE.fullmatch(ln)
        if not em:
            raise EvidenceError(f'{source}: bad event line at {i}: {ln!r}')
        idx, packed, addr, value = (int(x, 16) for x in em.groups())
        if idx != i:
            raise EvidenceError(f'{source}: event indices not contiguous, got {idx}, wanted {i}')
        kind = packed >> 16
        if kind not in (1, 2):
            raise EvidenceError(f'{source}: unknown event kind {kind}')
        event = Event(idx, kind, packed & 0xFFFF, addr, value)
        if i and event.cycle < events[-1].cycle:
            raise EvidenceError(f'{source}: decreasing 16-bit relative timestamps')
        events.append(event)
    if not (1 <= len(events) <= MAX_EVENTS):
        raise EvidenceError(f'{source}: event count out of range {len(events)}')
    # Observed T3 protocol uses low 8 bits of first word for the count.
    if (word & 0xFF) != len(events):
        raise EvidenceError(f'{source}: T3 count mismatch: {word & 0xff} vs {len(events)}')
    expected = 0 if command == 0 else 1 << (command - 1)
    writes = [e for e in events if e.kind == 2]
    if len(writes) != 1 or writes[0] != events[-1]:
        raise EvidenceError(f'{source}: expected one final LED_WRITE')
    if writes[0].addr != 0x20000000 or writes[0].value != expected:
        raise EvidenceError(f'{source}: invalid final LED MMIO write')
    fetches = [e for e in events if e.kind == 1]
    if not fetches:
        raise EvidenceError(f'{source}: no FETCH events')
    for e in fetches:
        if e.addr % 4 or e.addr >= 1024:
            raise EvidenceError(f'{source}: unaligned or out-of-ROM FETCH at 0x{e.addr:08x}')
    return word, command_word, events


def rom_words(data: bytes) -> list[int]:
    try:
        txt = data.decode('utf-8-sig')
        words = [int(x, 16) for x in txt.split()]
    except (UnicodeDecodeError, ValueError) as exc:
        raise EvidenceError('ROM is not a valid whitespace-separated hex file') from exc
    if not words or any(w < 0 or w > 0xffffffff for w in words):
        raise EvidenceError('ROM hex is empty or contains non-32-bit words')
    return words


def common_suffix(seqs: list[list[Event]]) -> list[Event]:
    if not seqs:
        return []
    reversed_seqs = [list(reversed(seq)) for seq in seqs]
    matching = []
    for elements in zip(*reversed_seqs):
        if len({e.signature for e in elements}) != 1:
            break
        matching.append(elements[0])
    return list(reversed(matching))


def matches_poll_pattern(prefix: list[Event]) -> bool:
    if not prefix or any(e.kind != 1 for e in prefix):
        return False
    addrs = tuple(e.addr for e in prefix)
    return any(all(addr == POLL_CYCLE[(shift+i) % len(POLL_CYCLE)] for i, addr in enumerate(addrs))
               for shift in range(len(POLL_CYCLE)))


def _signed_imm(value: int, width: int) -> int:
    if value & (1 << (width - 1)):
        return value - (1 << width)
    return value


def direct_target(addr: int, instruction: int) -> Optional[int]:
    """Encode-derived immediate target for B-type branch/JAL; not whether taken."""
    op = instruction & 0x7f
    if op == 0x63:
        imm = (((instruction >> 31) & 1) << 12 | ((instruction >> 7) & 1) << 11 |
               ((instruction >> 25) & 0x3f) << 5 | ((instruction >> 8) & 0xf) << 1)
        return (addr + _signed_imm(imm, 13)) & 0xffffffff
    if op == 0x6f:
        imm = (((instruction >> 31) & 1) << 20 | ((instruction >> 12) & 0xff) << 12 |
               ((instruction >> 20) & 1) << 11 | ((instruction >> 21) & 0x3ff) << 1)
        return (addr + _signed_imm(imm, 21)) & 0xffffffff
    return None


def _fmtpc(e: Event):
    return f'0x{e.addr:03X}'


def analyze(read: Callable[[str], bytes], rom_override: Optional[bytes] = None, rom_label: str = 'boot.hex') -> dict:
    try:
        manifest = json.loads(read('manifest.json').decode('utf-8-sig'))
        text = read('runs.csv').decode('utf-8-sig')
        csv_rows = list(csv.DictReader(io.StringIO(text)))
        json_rows = json.loads(read('runs.json').decode('utf-8-sig'))
    except (KeyError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EvidenceError(f'Invalid or incomplete campaign manifest: {exc}') from exc
    if not csv_rows or len(csv_rows) != len(json_rows):
        raise EvidenceError('runs.csv / runs.json cardinality mismatch')
    if int(manifest.get('rounds', 0)) * len(manifest.get('command_sequence', [])) != len(csv_rows):
        raise EvidenceError('Manifest campaign length differs from runs.csv')
    if [int(row['requested_command']) for row in csv_rows] != manifest['command_sequence'] * manifest['rounds']:
        raise EvidenceError('Command order differs from manifest')
    rom_bytes = rom_override if rom_override is not None else read('boot.hex')
    rom = rom_words(rom_bytes)
    runs = []
    for position, row in enumerate(csv_rows, 1):
        index, command = int(row['index']), int(row['command'])
        if index != position or not 0 <= command <= 6 or row['status'] != 'PASS':
            raise EvidenceError(f'Run {position}: invalid index, command, or upstream status')
        rj = json_rows[position - 1]
        for fld in ('index', 'command', 'events', 'fetches', 'led_write', 'sha256', 'raw_file'):
            if str(rj[fld]).lower() != str(row[fld]).lower():
                raise EvidenceError(f'Run {position}: CSV/JSON disagree on {fld}')
        flags = rj.get('flags')
        if not flags or flags.get('done') is not True or any(flags.get(k) is not False for k in ('truncated', 'overlap', 'wrapped', 'capturing')):
            raise EvidenceError(f'Run {position}: invalid/unavailable upstream flags')
        raw_file = _safe_relative(row['raw_file'])
        data = read(raw_file)
        digest = hashlib.sha256(data).hexdigest()
        if digest.lower() != row['sha256'].lower():
            raise EvidenceError(f'Run {position}: raw SHA256 mismatch (archive corrupted/changed)')
        header, headcmd, events = parse_dump(data, command, raw_file)
        if len(events) != int(row['events']) or sum(x.kind == 1 for x in events) != int(row['fetches']):
            raise EvidenceError(f'Run {position}: actual events/fetches disagree with CSV')
        expected = 0 if command == 0 else 1 << (command - 1)
        if int(row['led_write'], 16) != expected or int(row['expected_led_write'], 16) != expected:
            raise EvidenceError(f'Run {position}: CSV declared wrong MMIO state')
        runs.append(Run(index, command, raw_file, digest, header, headcmd, events, row))
    # An externally recorded probe script is archived and manifest hash is checkable.
    recorded_probe_hash = manifest.get('probe_sha256')
    if recorded_probe_hash:
        local_probe_hash = hashlib.sha256(read('probe_lab03_2_serial.ps1')).hexdigest()
        if local_probe_hash != recorded_probe_hash:
            raise EvidenceError('probe script SHA256 differs from manifest')

    observed_words: dict[int, set[int]] = collections.defaultdict(set)
    for run in runs:
        for e in run.fetches:
            observed_words[e.addr].add(e.value)
    word_conflicts = {pc: sorted(values) for pc, values in observed_words.items() if len(values) != 1}
    if word_conflicts:
        raise EvidenceError(f'Inconsistent instruction words for same PC: {word_conflicts}')
    canonical_words = {pc: next(iter(words)) for pc, words in observed_words.items()}
    groups = collections.defaultdict(list)
    for r in runs:
        groups[r.command].append(r)
    group_info = {}
    for cmd, group in sorted(groups.items()):
        if len(group) < 2:
            raise EvidenceError(f'Need multiple captures to test within-command invariance, command {cmd}')
        # LAB-03.2-specific semantic boundary: first dispatch FETCH at PC 0x048.
        # A purely "longest common suffix" can start in the polling loop and
        # give misleading core sizes when several captures share its tail.
        anchor = 0x048
        cuts = []
        for run in group:
            hits = [i for i, e in enumerate(run.events) if e.kind == 1 and e.addr == anchor]
            if len(hits) != 1:
                raise EvidenceError(f'Run {run.index}: expected exactly one PC=0x048 dispatch anchor')
            cuts.append(hits[0])
        suffix = group[0].events[cuts[0]:]
        if not suffix or suffix[-1].kind != 2:
            raise EvidenceError(f'No completed normalized core for command {cmd}')
        for run, cut in zip(group,cuts):
            run.poll_prefix = run.events[:cut]
            run.common_core = run.events[cut:]
            if [e.signature for e in run.common_core] != [e.signature for e in suffix]:
                raise EvidenceError(f'Run {run.index}: command-dispatch core differs from peers')
            if not matches_poll_pattern(run.poll_prefix):
                raise EvidenceError(f'Run {run.index}: varying prefix not a consecutive UART poll fetch window')
        group_info[str(cmd)] = {
            'runs': len(group),
            'stable_core_events': len(suffix),
            'stable_core_fetches': sum(e.kind == 1 for e in suffix),
            'core_start_pc': suffix[0].addr,
            'poll_prefix_fetches_by_run': {str(r.index): len(r.poll_prefix) for r in group},
            'core_signature_sha256': hashlib.sha256(json.dumps([e.signature for e in suffix]).encode('utf-8')).hexdigest(),
            'core_events': [e.signature for e in suffix],
            'core_fetch_pcs': [e.addr for e in suffix if e.kind == 1],
        }

    mismatch_instances = []
    rom_matches = 0
    for run in runs:
        for e in run.fetches:
            wanted = rom[e.addr//4] if e.addr//4 < len(rom) else None
            if e.value == wanted:
                rom_matches += 1
            else:
                mismatch_instances.append({'run': run.index, 'pc': e.addr, 'observed': e.value, 'rom': wanted})
    distinct_rom_mismatches = sorted({d['pc'] for d in mismatch_instances})
    return {
        'manifest': manifest,
        'runs': runs,
        'groups': group_info,
        'observed_words': canonical_words,
        'rom_words': rom,
        'rom_label': rom_label,
        'rom_sha256': hashlib.sha256(rom_bytes).hexdigest(),
        'rom_matches': rom_matches,
        'rom_mismatches': mismatch_instances,
        'rom_mismatch_distinct_pcs': distinct_rom_mismatches,
        'total_fetches': sum(len(r.fetches) for r in runs),
    }


def write_outputs(result: dict, out: Path):
    out.mkdir(parents=True, exist_ok=True)
    runs: list[Run] = result['runs']
    rom: list[int] = result['rom_words']
    with (out/'decoded_events.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        w=csv.writer(stream)
        w.writerow(['run','command','event_index','kind','cycle','address','value','phase','reference_rom_word','rom_match','direct_branch_or_jal_target'])
        for run in runs:
            for e in run.events:
                expected = rom[e.addr//4] if e.kind == 1 and e.addr//4 < len(rom) else None
                t = direct_target(e.addr,e.value) if e.kind == 1 else None
                w.writerow([run.index,run.command,e.index,'FETCH' if e.kind==1 else 'LED_WRITE',e.cycle,
                            f'0x{e.addr:08X}',f'0x{e.value:08X}',
                            'poll_prefix' if e in run.poll_prefix else 'stable_core',
                            '' if expected is None else f'0x{expected:08X}',
                            '' if expected is None else ('PASS' if e.value==expected else 'MISMATCH'),
                            '' if t is None else f'0x{t:08X}'])
    with (out/'observed_words.csv').open('w', encoding='utf-8-sig', newline='') as stream:
        w=csv.writer(stream);w.writerow(['pc','observed_word','reference_rom_word','match','branch_or_jal_direct_target'])
        for pc, word in sorted(result['observed_words'].items()):
            expected = rom[pc//4] if pc//4 < len(rom) else None
            target = direct_target(pc,word)
            w.writerow([f'0x{pc:08X}',f'0x{word:08X}', '' if expected is None else f'0x{expected:08X}',
                        'PASS' if expected==word else 'MISMATCH', '' if target is None else f'0x{target:08X}'])
    summary = {
        'version': 'LAB03.4-v0.1',
        'scope': 'T3/E/Z capture integrity and FETCH bus event content; NOT retired-instruction or cycle RTL equivalence',
        'run_count': len(runs),
        'all_raw_hashes_verified': True,
        'total_fetches': result['total_fetches'],
        'distinct_pc': len(result['observed_words']),
        'cross_trace_word_conflicts': 0,
        'rom_reference': result['rom_label'],
        'rom_sha256': result['rom_sha256'],
        'rom_match_fetches': result['rom_matches'],
        'rom_mismatch_fetches': len(result['rom_mismatches']),
        'rom_mismatch_unique_pcs': len(result['rom_mismatch_distinct_pcs']),
        'rom_reference_match_status': 'PASS' if not result['rom_mismatches'] else 'MISMATCH',
        'groups': {k: {n:v for n,v in info.items() if n!='core_events'} for k,info in result['groups'].items()},
        'provenance': result['manifest'],
    }
    (out/'summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    report = []
    report.append('# LAB-03.4 — независимый аудит аппаратных трасс PicoRV32')
    report.append('')
    report.append('**Статус:** `RAW_INTEGRITY_PASS`, `CAPTURE_STRUCTURE_PASS`, `OBSERVED_WORD_CONSISTENCY_PASS`, `POLL_CORE_NORMALIZATION_PASS`.')
    report.append('**Ограничение:** FETCH — подтверждённое чтение инструкции, не retirement. Данные захвата не являются потактовым RTL-трейсом.')
    report.append('')
    report.append('## Проверенные факты')
    report.append('')
    report.append(f'- Файлов: **{len(runs)}**; SHA-256 сырых UART-дампов подтверждены: **{len(runs)}/{len(runs)}**.')
    report.append(f'- FETCH: **{result["total_fetches"]}**; уникальных PC: **{len(result["observed_words"])}**; конфликтов слов одного PC: **0**.')
    report.append(f'- ROM: `{result["rom_label"]}` (SHA-256 `{result["rom_sha256"]}`).')
    report.append(f'- Сверка FETCH с этим ROM: **{result["rom_matches"]} совпадений / {len(result["rom_mismatches"])} несовпадений**; уникальных несовпадающих PC **{len(result["rom_mismatch_distinct_pcs"])}**.')
    report.append('- SHA-256 битстрима и User Code сохранены из декларации манифеста; **фактическое содержимое SRAM не считывалось**.')
    report.append('')
    report.append('## Одинаковый хвост, изменчивый префикс')
    report.append('')
    report.append('| Команда | Захватов | Общий хвост FETCH | Префиксы FETCH по порядку запусков | Обязательный конец |')
    report.append('|---|---:|---:|---|---|')
    for cmd, info in sorted(result['groups'].items(),key=lambda x:int(x[0])):
        prefixes = ', '.join(f'{k}:{v}' for k,v in info['poll_prefix_fetches_by_run'].items())
        report.append(f'| {cmd} | {info["runs"]} | {info["stable_core_fetches"]} | {prefixes} | LED_WRITE=0x{0 if int(cmd)==0 else 1<<(int(cmd)-1):08X} |')
    report.append('')
    report.append('Во всех 12 снимках изменяется только начальный участок FETCH с циклическими адресами `0x038 → 0x03C → 0x040 → 0x044`.')
    report.append('Начиная с `0x048`, все события каждой команды совпадают по `(kind, PC/address, word/value)`; относительные циклы и индексы в нормализации намеренно исключены.')
    report.append('Это локализует вариативность; объяснение асинхронной фазой UART/CPU правдоподобно, но требует независимой проверки.')
    report.append('')
    report.append('## Аппаратные захваты')
    report.append('')
    report.append('| Run | Команда | FETCH | Префикс FETCH | Хвост FETCH | События |')
    report.append('|---:|---:|---:|---:|---:|---:|')
    for run in runs:
        report.append(f'| {run.index} | {run.command} | {len(run.fetches)} | {len(run.poll_prefix)} | {len(run.common_core)-1} | {len(run.events)} |')
    report.append('')
    report.append('## Примеры архитектурно важных переходов')
    report.append('')
    for pc in (0x064,0x084):
        if pc in result['observed_words']:
            word=result['observed_words'][pc]
            target=direct_target(pc,word)
            report.append(f'- FETCH PC `0x{pc:03X}`, слово `0x{word:08X}`, B-type branch target `0x{target:03X}` (адрес вычислен из непосредственного смещения, **не** доказательство принятого перехода).')
    report.append('Записи содержат также выборку следующего последовательного PC до целевого адреса; это совместимо с look-ahead. Последовательность FETCH не должна автоматически трактоваться как последовательность retired-инструкций.')
    report.append('')
    report.append('## Несовпадение ROM — отдельный блокер')
    report.append('')
    examples = result['rom_mismatches'][:]
    selected=[];seen=set()
    for e in examples:
        if e['pc'] not in seen:
            selected.append(e);seen.add(e['pc'])
        if len(selected)>=6:break
    report.append('| PC | Захвачено в UART | Слово эталона ROM |')
    report.append('|---|---|---|')
    for e in selected:
        ref='N/A' if e['rom'] is None else f'0x{e["rom"]:08X}'
        report.append(f'| 0x{e["pc"]:03X} | 0x{e["observed"]:08X} | {ref} |')
    report.append('')
    report.append('Наличие несовпадений означает `ROM_REFERENCE_MISMATCH`, **не** дефект FPGA. Зафиксирован `working_tree_dirty=true` и хеш исходного .fs объявлен, но не проверен чтением SRAM.')
    report.append('Для независимого сравнения нужен ROM именно той сборки, которая записана в FPGA, плюс RTL-трейс, полученный на этой же версии.')
    report.append('')
    report.append('## Классы доказательств')
    report.append('')
    report.append('- `CAPTURE/MMIO` — подтверждён отдельно в LAB-03.3; этот анализ независимо проверил структуру и MMIO всех 12 дампов.')
    report.append('- `OBSERVED_WORD_CONSISTENCY_PASS` — да, 12/12; это **не** независимая проверка правильности ROM.')
    report.append(f'- `ROM_REFERENCE_MATCH` — **{"PASS" if not result["rom_mismatches"] else "MISMATCH / BLOCKED"}** для указанных входных данных.')
    report.append('- `BUS_FETCH_TRACE_EQUIVALENCE` (RTL) — **NOT TESTED**: эталонный RTL-поток из той же сборки отсутствует.')
    report.append('- `RETIRED_INSTRUCTION_EQUIVALENCE` — **NOT CLAIMED**: устройство регистрации не наблюдает retirement.')
    report.append('')
    report.append('Файлы `decoded_events.csv`, `observed_words.csv`, `summary.json` сохраняют все проверяемые промежуточные результаты.')
    (out/'report.md').write_text('\n'.join(report)+'\n',encoding='utf-8')
    return summary


def main(argv=None):
    parser = argparse.ArgumentParser(description='LAB-03.4: offline PicoRV32 fetch-bus campaign audit (does not touch FPGA).')
    parser.add_argument('--evidence',type=Path,required=True,help='LAB03_3_EVIDENCE.zip or extracted campaign directory')
    parser.add_argument('--out',type=Path,required=True,help='Output folder (prefer under ignored build/)')
    parser.add_argument('--rom',type=Path,default=None,help='Alternative exact-build ROM hex; omit to use evidence boot.hex')
    args=parser.parse_args(argv)
    try:
        read=source_reader(args.evidence)
        rom_override=args.rom.read_bytes() if args.rom else None
        res=analyze(read,rom_override=rom_override,rom_label=str(args.rom) if args.rom else 'boot.hex (inside evidence)')
        summary=write_outputs(res,args.out)
        print(f'LAB03_4_RAW_INTEGRITY_PASS: runs={summary["run_count"]}, hashes={summary["run_count"]}')
        print(f'LAB03_4_CAPTURE_STRUCTURE_PASS: FETCH={summary["total_fetches"]} LED_WRITE={summary["run_count"]}')
        print(f'LAB03_4_OBSERVED_WORD_CONSISTENCY_PASS: distinct_PCs={summary["distinct_pc"]}')
        for cmd,grp in summary['groups'].items():
            print(f'LAB03_4_STABLE_CORE_PASS: cmd={cmd}, core_FETCH={grp["stable_core_fetches"]}, runs={grp["runs"]}')
        if summary['rom_mismatch_fetches']:
            print(f'LAB03_4_ROM_REFERENCE_MISMATCH: mismatched_FETCH={summary["rom_mismatch_fetches"]}/{summary["total_fetches"]}; no FPGA fault inferred')
        else:
            print('LAB03_4_ROM_WORDS_MATCH: all observed FETCH words matched provided ROM (not full RTL equivalence)')
        print('LAB03_4_RTL_TRACE_EQUIVALENCE_NOT_TESTED: matching RTL capture missing')
        print(f'LAB03_4_REPORT: {args.out.resolve() / "report.md"}')
        return 0
    except (EvidenceError,FileNotFoundError,KeyError,ValueError,zipfile.BadZipFile) as exc:
        print(f'LAB03_4_EVIDENCE_FAIL: {exc}',file=sys.stderr)
        return 1


if __name__=='__main__':
    sys.exit(main())
