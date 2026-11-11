#!/usr/bin/env python3
"""Reproduce offline HTML from index.template.html and questions.json (stdlib only)."""
from __future__ import annotations
import argparse
import json
from pathlib import Path

BASE=Path(__file__).resolve().parent

def build():
    questions=json.loads((BASE/'questions.json').read_text(encoding='utf-8'))
    tpl=(BASE/'index.template.html').read_text(encoding='utf-8')
    assert tpl.count('__QUESTIONS__') == 1, 'Expected one JSON insert marker'
    return tpl.replace('__QUESTIONS__',json.dumps(questions,ensure_ascii=False,separators=(',',':')))

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--check', action='store_true', help='Compare to committed standalone HTML without modifying it')
    ns=p.parse_args()
    file=BASE/'PicoRV32_QuizLab_v1.0.html'
    output=build()
    if ns.check:
        if file.read_text(encoding='utf-8')!=output:raise SystemExit('QUIZ_HTML_MISMATCH')
        print('QUIZ_STANDALONE_BUILD_PASS')
    else:
        file.write_text(output,encoding='utf-8',newline='\n')
        print('QUIZ_STANDALONE_REBUILT:',file)

if __name__=='__main__':main()
