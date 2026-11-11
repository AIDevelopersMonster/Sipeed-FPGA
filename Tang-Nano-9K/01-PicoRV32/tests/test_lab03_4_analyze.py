#!/usr/bin/env python3
"""LAB-03.4 offline synthetic regression tests; no COM/JTAG required."""
from __future__ import annotations
import csv
import hashlib
import importlib.util
import io
import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE=Path(__file__).resolve()
TOOL=HERE.parents[1] / 'tools' / 'lab03_4_analyze.py'
spec=importlib.util.spec_from_file_location('lab03_4_analyze',TOOL)
mod=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=mod
spec.loader.exec_module(mod)


def corpus():
    # The 0x048 dispatch is the shared phase boundary; 0x038..0x044 polls.
    prefixes={
        1:[0x03C,0x040,0x044],
        2:[0x038,0x03C,0x040,0x044],
        3:[0x040,0x044,0x038,0x03C,0x040,0x044],
        4:[0x044,0x038,0x03C,0x040,0x044],
    }
    commands=[4,0,4,0]
    # Each group must have invariant core but each run has a variable polling prefix.
    core={
        4:[(0x048,0x05400413),(0x084,0x048E0C63)],
        0:[(0x048,0x05400413),(0x064,0x048E0463)],
    }
    values={0x038:0x01c2a383,0x03c:0x0013f393,0x040:0xfe038ce3,0x044:0x0182ae03,
            0x048:0x05400413,0x064:0x048e0463,0x084:0x048e0c63}
    entries={};rows=[];obj=[];probe=b'# synthetic probe for unit tests\n'
    for i,command in enumerate(commands,1):
        pcs=prefixes[i]+[pc for pc,val in core[command]]
        evt=[(1,pc,values[pc]) for pc in pcs]+[(2,0x20000000,0 if command==0 else 8)]
        raw=[f'T3:038001{len(evt):02X}:000000{ord(str(command)):02X}']
        raw += [f'E:{j:08X}:{(kind<<16)| (j*4):08X}:{pc:08X}:{val:08X}' for j,(kind,pc,val) in enumerate(evt)]
        raw.append('Z')
        data=('\r\n'.join(raw)+'\r\n').encode('utf-8')
        filename=f'raw/run_{i:03d}_led_{command}.txt'
        entries[filename]=data
        led=f'0x{evt[-1][2]:08X}'
        row={'index':i,'requested_command':command,'command':command,'events':len(evt),'fetches':len(evt)-1,
             'led_write':led,'expected_led_write':led,'status':'PASS','sha256':hashlib.sha256(data).hexdigest(),
             'raw_file':filename,'console_file':f'console/run_{i:03d}.txt','utc':'2026-10-20T21:46:42+00:00'}
        rows.append(row)
        obj.append({**row,'flags':{'done':True,'truncated':False,'overlap':False,'wrapped':False,'capturing':False},'error':None})
    manifest={'rounds':2,'command_sequence':[4,0], 'probe_sha256':hashlib.sha256(probe).hexdigest(),
              'bitstream':{'sha256':'not-verified'},'git':{'working_tree_dirty':True}}
    out=io.StringIO()
    writer=csv.DictWriter(out,fieldnames=list(rows[0]))
    writer.writeheader();writer.writerows(rows)
    entries.update({'manifest.json':json.dumps(manifest).encode(),'runs.csv':out.getvalue().encode(),
                    'runs.json':json.dumps(obj).encode(), 'probe_lab03_2_serial.ps1':probe})
    rom=[0x13]*256
    for pc,val in values.items():rom[pc//4]=val
    entries['boot.hex']=(''.join(f'{v:08X}\n' for v in rom)).encode('utf-8')
    return entries


class TraceTests(unittest.TestCase):
    def setUp(self):
        self.entries=corpus()

    def reader(self):
        return lambda name:self.entries[name]

    def test_normalized_core_and_independent_rom_match(self):
        a=mod.analyze(self.reader())
        self.assertEqual(len(a['runs']),4)
        self.assertEqual(a['total_fetches'],sum(len(r.fetches) for r in a['runs']))
        self.assertEqual(len(a['rom_mismatches']),0)
        self.assertEqual(a['groups']['4']['stable_core_fetches'],2)
        self.assertEqual(a['groups']['0']['stable_core_fetches'],2)
        self.assertEqual(a['groups']['4']['poll_prefix_fetches_by_run'],{'1':3,'3':6})
        self.assertEqual(a['groups']['0']['poll_prefix_fetches_by_run'],{'2':4,'4':5})
        with tempfile.TemporaryDirectory() as temp:
            s=mod.write_outputs(a,Path(temp))
            self.assertEqual(s['rom_reference_match_status'],'PASS')
            self.assertTrue((Path(temp)/'decoded_events.csv').exists())

    def test_reference_rom_mismatch_is_visible_not_hardware_failure(self):
        lines=self.entries['boot.hex'].decode().splitlines()
        lines[0x048//4]='00000013'
        self.entries['boot.hex']=('\n'.join(lines)+'\n').encode()
        a=mod.analyze(self.reader())
        self.assertEqual(len(a['rom_mismatches']),4)
        self.assertEqual(len(a['observed_words'][0x048].to_bytes(4,'big')),4)

    def test_corrupt_raw_hash_fails(self):
        key='raw/run_001_led_4.txt'
        self.entries[key]=self.entries[key].replace(b'05400413',b'05500413')
        with self.assertRaisesRegex(mod.EvidenceError,'SHA256 mismatch'):
            mod.analyze(self.reader())

    def test_inconsistent_pc_word_detected_even_with_rehashed_csv_json(self):
        key='raw/run_003_led_4.txt'
        data=self.entries[key].replace(b'05400413',b'05500413')
        self.entries[key]=data
        self._reindex_hash(3,data)
        with self.assertRaisesRegex(mod.EvidenceError,'Inconsistent instruction words'):
            mod.analyze(self.reader())

    def test_unexpected_prefix_rejected(self):
        key='raw/run_003_led_4.txt'
        data=self.entries[key].replace(b':00000038:01C2A383',b':00000030:01C2A383')
        self.entries[key]=data
        self._reindex_hash(3,data)
        with self.assertRaisesRegex(mod.EvidenceError,'not a consecutive UART poll'):
            mod.analyze(self.reader())

    def test_invalid_header_count_rejected(self):
        sample=self.entries['raw/run_001_led_4.txt']
        with self.assertRaisesRegex(mod.EvidenceError,'T3 count mismatch'):
            mod.parse_dump(sample.replace(b'T3:03800106',b'T3:03800105'),4,'sample')

    def test_branch_target_is_derived_not_retirement(self):
        self.assertEqual(mod.direct_target(0x064,0x048e0463),0x0AC)
        self.assertEqual(mod.direct_target(0x084,0x048e0c63),0x0DC)
        self.assertIsNone(mod.direct_target(0x048,0x05400413))

    def test_zip_reader(self):
        with tempfile.TemporaryDirectory() as temp:
            z=Path(temp)/'sample.zip'
            with zipfile.ZipFile(z,'w',zipfile.ZIP_DEFLATED) as f:
                for name,data in self.entries.items():f.writestr(name,data)
            a=mod.analyze(mod.source_reader(z))
            self.assertEqual(len(a['runs']),4)

    def _reindex_hash(self,index,data):
        new_sha=hashlib.sha256(data).hexdigest()
        stream=io.StringIO(self.entries['runs.csv'].decode())
        rows=list(csv.DictReader(stream));fields=list(rows[0].keys())
        rows[index-1]['sha256']=new_sha
        buf=io.StringIO();writer=csv.DictWriter(buf,fieldnames=fields);writer.writeheader();writer.writerows(rows)
        self.entries['runs.csv']=buf.getvalue().encode()
        js=json.loads(self.entries['runs.json'].decode())
        js[index-1]['sha256']=new_sha
        self.entries['runs.json']=json.dumps(js).encode()


if __name__=='__main__':
    unittest.main(verbosity=2)
