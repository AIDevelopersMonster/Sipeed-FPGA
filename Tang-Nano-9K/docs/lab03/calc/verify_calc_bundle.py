#!/usr/bin/env python3
"""Read-only, stdlib-only integrity check of LAB-03 Calc and source ROM."""
from pathlib import Path
from zipfile import ZipFile
import hashlib, json, re, xml.etree.ElementTree as ET

D=Path(__file__).resolve().parent
EXPECTED_ROM='14b85bc20ce43cdf4ce09ef1db7a20af5677c1c728c64b71258f6c63ab5b8a3d'
sha=lambda p:hashlib.sha256((D/p).read_bytes()).hexdigest()
assert sha('lab03_boot.hex')==EXPECTED_ROM, 'Pinned ROM changed'
rom=(D/'lab03_boot.hex').read_text(encoding='ascii').splitlines()
assert len(rom)==256 and all(re.fullmatch(r'[0-9a-fA-F]{8}',x) for x in rom)
assert len([x for x in rom if x.lower()=='00000013'])==54
assert rom[0x100//4].lower()=='01d2a023'
assert rom[0x84//4].lower()=='048e0c63'
assert rom[0xe4//4].lower()=='01c0006f'
for filename in ('LAB03_PicoRV32_Excel_Observatory_v1.0.xlsx', 'LAB03_PicoRV32_Excel_Observatory_v1.1_RV32I.xlsx'):
 with ZipFile(D/filename) as z:
  assert z.testzip() is None,filename
  w=ET.fromstring(z.read('xl/workbook.xml'))
  names=[x.attrib['name'] for x in w.findall('.//{http://schemas.openxmlformats.org/spreadsheetml/2006/main}sheet')]
  if 'v1.1' in filename:
   assert len(names)>=13 and all(x in names for x in ['ПУЛЬТ','РАЗБОР RV32I','КАТАЛОГ БИТОВ','10 КАРТОЧЕК','МОДЕЛЬ MMIO']),names
with ZipFile(D/'LAB03_PicoRV32_Excel_Observatory_v1.1_RV32I.ods') as z:
 assert z.testzip() is None
 assert z.read('mimetype')==b'application/vnd.oasis.opendocument.spreadsheet'
 content=z.read('content.xml')
 for sheet in ['РАЗБОР RV32I','КАТАЛОГ БИТОВ','10 КАРТОЧЕК','ПУЛЬТ','МОДЕЛЬ MMIO']:
  assert sheet.encode('utf-8') in content,sheet
expected={}
for line in (D/'SHA256SUMS.txt').read_text(encoding='utf-8').splitlines():
 if not line.strip():continue
 h,sep,path=line.partition('  ')
 assert sep and re.fullmatch('[0-9a-f]{64}',h) and path and path not in expected
 expected[path]=h
assert set(expected)==set(p.name for p in D.iterdir() if p.is_file() and p.name!='SHA256SUMS.txt'), 'Checksum list not exact'
for name,h in expected.items():assert sha(name)==h, f'SHA256 mismatch: {name}'
print('CALC_BUNDLE_PASS: 256 ROM words, 202 non-NOP, 54 NOP, ODS/XLSX structural PASS, SHA256 files=',len(expected))
