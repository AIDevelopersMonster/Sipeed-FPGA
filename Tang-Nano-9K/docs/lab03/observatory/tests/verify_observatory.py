#!/usr/bin/env python3
"""Independent Python audit of the bundled LAB-03 teaching evidence.

Only stdlib; does not start a browser or touch USB/FPGA.
"""
from __future__ import annotations
from pathlib import Path
from html.parser import HTMLParser
from hashlib import sha256
import json, re, sys

ROOT = Path(__file__).resolve().parents[1]
ROM_SHA256 = '14b85bc20ce43cdf4ce09ef1db7a20af5677c1c728c64b71258f6c63ab5b8a3d'
EXPECTED_BITSTREAM = '62596847427f0258cb729a8b3c042ab7e0f39a8725990ba39a831b98c6554f13'

class IDs(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = []
    def handle_starttag(self, tag, attrs):
        values = dict(attrs)
        if 'id' in values: self.ids.append(values['id'])


def audit() -> None:
    rom_bytes=(ROOT / 'data/lab03_boot.hex').read_bytes()
    canonical_rom=rom_bytes.replace(b'\r\n',b'\n')
    assert sha256(canonical_rom).hexdigest()==ROM_SHA256, 'ROM does not match published LAB-03'
    words=[int(x,16) for x in canonical_rom.decode('ascii').splitlines()]
    assert len(words)==256 and words[0x48//4]==0x05400413

    bundle=json.loads((ROOT / 'data/campaign.json').read_text(encoding='utf-8'))
    assert bundle['romSha256']==ROM_SHA256
    assert bundle['bitstreamSha256Declared']==EXPECTED_BITSTREAM
    assert bundle['source']=='real-hardware-archive'
    assert re.fullmatch(r'[0-9a-f]{64}',bundle['archiveSha256'])
    archive=ROOT/'evidence/LAB03_3_EVIDENCE.zip'
    assert archive.is_file() and sha256(archive.read_bytes()).hexdigest()==bundle['archiveSha256'], 'Evidence archive hash mismatch'
    rows=bundle['boardCaptures']
    assert len(rows)==12
    fetch_total=0;groups={0:[],4:[]};raw_hashes=set()
    for c in rows:
        b=c['trace'].encode('ascii')
        digest=sha256(b).hexdigest()
        assert digest==c['rawSha256'], 'SHA discrepancy'
        raw_hashes.add(digest)
        lines=b.decode('ascii').strip().splitlines()
        status,command = (int(x,16) for x in lines[0].split(':')[1:])
        assert (status>>24)==3 and ((status>>16)&255)==128 and (status&0x100)
        assert status&0x1E00==0 and (status&255)==len(lines)-2
        assert lines[-1]=='Z'
        assert chr(command)==c['command'] and c['status']=='PASS'
        events=[]
        for i,line in enumerate(lines[1:-1]):
            m=re.fullmatch(r'E:([0-9a-fA-F]{8}):([0-9a-fA-F]{8}):([0-9a-fA-F]{8}):([0-9a-fA-F]{8})',line)
            assert m, (c['run'],i)
            idx,meta,addr,value=[int(x,16) for x in m.groups()]
            assert idx==i and meta>>18==0
            kind=meta>>16
            assert kind in (1,2)
            if kind==1: assert addr%4==0 and addr<1024 and words[addr//4]==value
            else: assert addr==0x20000000
            events.append((kind,addr,value))
        assert events[-1][0]==2 and sum(e[0]==2 for e in events)==1
        cmd=int(c['command']);assert events[-1][2]==(0 if cmd==0 else 1<<(cmd-1))
        core_idxs=[i for i,e in enumerate(events) if e[0]==1 and e[1]==0x48]
        assert len(core_idxs)==1
        idx=core_idxs[0]
        assert all(e[0]==1 and e[1] in (0x38,0x3c,0x40,0x44) for e in events[:idx])
        core=events[idx:];assert sum(e[0]==1 for e in core)==(14 if cmd==0 else 22)
        groups[cmd].append((c['run'],len(events)-1,idx,core))
        assert c['fetches']==len(events)-1 and c['events']==len(events)
        fetch_total+=len(events)-1
    assert fetch_total==269 and len(groups[0])==6 and len(groups[4])==6
    for cmd,arr in groups.items():
        assert len({tuple(x[3]) for x in arr})==1, f'command {cmd} has inconsistent core signatures'
        assert len({x[1] for x in arr})>1, f'command {cmd} does not demonstrate varying polling'
    markup=(ROOT / 'index.html').read_text(encoding='utf-8')
    parser=IDs();parser.feed(markup)
    assert len(parser.ids)==len(set(parser.ids)), 'duplicate HTML id'
    required={'trace-select','trace-source-card','capture-chart','timeline','events-body',
              'event-disasm','led-bank','instruction-scope','instruction-grid','inspect-instruction-btn','compare-left','compare-right','rtl-file','hypothesis',
              'observations','interpretation','conclusion','connect-btn','capture-btn'}
    assert required.issubset(parser.ids), required.difference(parser.ids)
    assert (ROOT/'src/trace-core.mjs').is_file() and (ROOT/'src/app.mjs').is_file() and (ROOT/'src/instruction-catalog.mjs').is_file()
    assert all((ROOT/'methodics'/name).is_file() for name in (
        'LAB03_METHODICAL_RU.md','INSTALL_RUN_RU.md','ISA_REAL_DATA_RU.md',
        'STUDENT_REPORT_TEMPLATE_RU.md','TEACHER_GUIDE_RU.md'))
    assert 'https://' not in (ROOT/'src/app.mjs').read_text(encoding='utf-8'), 'app unexpectedly depends on network'
    print('LAB03_OBSERVATORY_EVIDENCE_PASS: board_runs=12 fetch=269 rom=256w core0=14 core4=22')
    print('LAB03_OBSERVATORY_HTML_PASS: interactive IDs, assets and no external JS API calls')
    print('LAB03_OBSERVATORY_SCOPE: archived real FPGA traces; LIVE Web Serial not exercised in this audit')

if __name__=='__main__':
    try: audit()
    except (AssertionError,ValueError,KeyError,UnicodeError,OSError) as e:
        print('LAB03_OBSERVATORY_VERIFY_FAIL:',e,file=sys.stderr)
        raise SystemExit(1)
