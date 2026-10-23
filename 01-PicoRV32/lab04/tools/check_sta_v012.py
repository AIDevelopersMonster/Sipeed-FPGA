#!/usr/bin/env python3
"""LAB-04 SDC/STA gate. Uses Python stdlib, does not run Gowin or program FPGA.

Report only if all clocks recognized; 0 setup/hold violated; nonnegative
recovery/removal; three active point-to-point CDC max_delay exceptions.
"""
import argparse
import html
import re
import sys
from pathlib import Path


def flatten_html(path: Path) -> str:
    data = path.read_text(encoding='utf-8', errors='replace')
    data = re.sub(r'<(script|style)\b[^>]*>.*?</\1>', ' ', data, flags=re.I|re.S)
    data = re.sub(r'<[^>]*>', ' ', data)
    data = html.unescape(data)
    return re.sub(r'\s+', ' ', data).strip()


def get_int(text, key):
    match = re.search(re.escape(key) + r'\s+(\d+)', text)
    if match is None: raise ValueError(f'Not found: {key}')
    return int(match.group(1))


def table_min(text, start, stop):
    a = text.find(start)
    if a < 0: raise ValueError(f'Missing table: {start}')
    b = text.find(stop, a+len(start))
    block = text[a+len(start): b if b > a else len(text)]
    vals = [float(m.group(1)) for m in re.finditer(r'(?<!\w)\d+\s+(-?\d+\.\d+)\s+u_', block)]
    return min(vals) if vals else None


def audit(path):
    t=flatten_html(path)
    setup=get_int(t,'Numbers of Setup Violated Endpoints')
    hold=get_int(t,'Numbers of Hold Violated Endpoints')
    paths=get_int(t,'Numbers of Paths Analyzed')
    ep=get_int(t,'Numbers of Endpoints Analyzed')
    # Names of PLL/CLKDIV generated clocks can vary; require all domains.
    clk_ok = all(re.search(x, t) for x in (r'clk27 Base 37\.037 27\.000',
        r'Generated 7\.936 126\.000',r'Generated 39\.682 25\.200'))
    # The report displays active SDC constraints near the end.
    tail=t[t.find('Timing Constraints Report:'):] if 'Timing Constraints Report:' in t else ''
    n_max=tail.count('TC_MAX_DELAY')
    active=n_max >= 3 and len(re.findall(r'TC_MAX_DELAY\s+Actived',tail)) >= 3
    # Use first listed (worst) recovery/removal path slacks.
    def worst(section, end):
        a=t.find(section)
        if a<0: return None
        b=t.find(end,a+len(section))
        segment=t[a:b if b>a else len(t)]
        m=re.search(r'\b1\s+(-?\d+\.\d+)\s+u_',segment)
        return float(m.group(1)) if m else None
    recovery=worst('Recovery Paths Table','Removal Paths Table')
    removal=worst('Removal Paths Table','Minimum Pulse Width Table')
    print(f'LAB04_V012_STA_GATE: paths={paths}, endpoints={ep}, setup_violations={setup}, hold_violations={hold}, recovery_min={recovery}, removal_min={removal}, max_delay_constraints={n_max}, active={active}, clocks={clk_ok}')
    failures=[]
    if setup: failures.append('setup violations remain')
    if hold: failures.append('hold violations remain')
    if recovery is None or recovery < 0: failures.append('recovery not verified nonnegative')
    if removal is None or removal < 0: failures.append('removal not verified nonnegative')
    if not clk_ok: failures.append('all 3 clocks not verified')
    if not active: failures.append('three bounded CDC constraints are not all active')
    if failures:
        print('LAB04_V012_STA_GATE_FAIL: '+ '; '.join(failures))
        return 1
    print('LAB04_V012_STA_GATE_PASS: only report-level gate; independently inspect raw STA; BOARD untested')
    return 0


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('timing_report_html',type=Path)
    args=parser.parse_args()
    try: sys.exit(audit(args.timing_report_html))
    except Exception as ex: print(f'LAB04_V012_STA_GATE_ERROR: {ex}',file=sys.stderr); sys.exit(2)
