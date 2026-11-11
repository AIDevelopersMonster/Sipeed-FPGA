#!/usr/bin/env python3
"""Read-only, dependency-free validation of QuizLab bank and offline HTML."""
from pathlib import Path
import json, hashlib, re
from collections import Counter
from build_standalone import build

D=Path(__file__).resolve().parent
Q=json.loads((D/'questions.json').read_text(encoding='utf-8'))
assert len(Q)==50, len(Q)
assert len({q['id'] for q in Q})==50
assert Counter(q['type'] for q in Q)=={'single':35,'multiple':6,'match':5,'order':4}
assert set(q['level'] for q in Q)=={'Базовый','Средний','Углублённый'}
assert len({q['section'] for q in Q})==3
assert Counter(q['section'] for q in Q)=={'LAB-03 · аппаратные данные':12,'RV32I · декодирование':20,'SoC · шина и периферия':18}
for q in Q:
 assert q['question'].strip(),q['id']
 assert q['evidence'] in {'BOARD','ROM','ISA','RTL','PROTOCOL','ANALYSIS','METHOD','LAB_NOTES'},q['id']
 assert isinstance(q['explanation'],str) and q['explanation'].strip(),q['id']
 assert isinstance(q['source'],str) and q['source'].startswith('https://github.com/AIDevelopersMonster/Sipeed-FPGA/'),q['id']
 assert isinstance(q['hint'],str) and q['hint'].strip(),q['id']
 if q['type'] in ('single','multiple'):
  assert isinstance(q['options'],list) and len(q['options'])==4,q['id']
  if q['type']=='single':
   assert isinstance(q['correct'],int) and 0<=q['correct']<4,q['id']
  else:
   assert isinstance(q['correct'],list) and len(q['correct']) in (2,3),q['id']
   assert len(set(q['correct']))==len(q['correct']),q['id']
   assert all(isinstance(i,int) and 0<=i<4 for i in q['correct']),q['id']
 elif q['type']=='match':
  assert len(q['options']['left'])==len(q['options']['right'])==len(q['correct']),q['id']
  assert sorted(q['correct'])==list(range(len(q['correct']))),q['id']
 elif q['type']=='order':
  assert len(q['options'])==len(q['correct']),q['id']
  assert sorted(q['correct'])==list(range(len(q['correct']))),q['id']
 else:raise AssertionError(q['id'])
js='window.PICO_QUESTIONS='+json.dumps(Q,ensure_ascii=False,separators=(',',':'))+';'
assert (D/'questions.js').read_text(encoding='utf-8')==js, 'JS question bank mismatch'
assert (D/'PicoRV32_QuizLab_v1.0.html').read_text(encoding='utf-8')==build(), 'Standalone HTML mismatch'
raw=(D/'PicoRV32_QuizLab_v1.0.html').read_text(encoding='utf-8')
assert raw.count('<html')==1 and '<script' in raw and 'type="module"' not in raw
print('QUIZ_STATIC_PASS: 50 questions; 35 single, 6 multiple, 5 match, 4 order; bundled HTML exact')
