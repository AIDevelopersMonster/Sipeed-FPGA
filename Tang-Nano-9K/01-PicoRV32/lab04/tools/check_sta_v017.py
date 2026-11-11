#!/usr/bin/env python3
"""Conservative v0.1.7 preliminary STA screen. NOT full CDC closure.

New video CDC wildcard constraints need an independent check that Gowin has
actually bound ALL 28 data bits. Even PRELIM_PASS is NOT a board-program gate.
Post-route report and logs must be audited before programmer_cli is used.
"""
import argparse,re,sys
from pathlib import Path
from check_sta_v013 import flat,parse_count,first_slack

BASE = Path(__file__).resolve().parents[1]
SDC=BASE/'constraints'/'lab04_cpu_video_v017.sdc'

def gate(report:Path,log:Path|None):
    errors=[]
    t=flat(report)
    if 'lab04_cpu_video_v017.sdc' not in t: errors.append('wrong/new SDC not listed')
    for key in ('Numbers of Paths Analyzed','Numbers of Endpoints Analyzed'):
        if parse_count(t,key)<1:errors.append(f'no {key}')
    setup=parse_count(t,'Numbers of Setup Violated Endpoints')
    hold=parse_count(t,'Numbers of Hold Violated Endpoints')
    if setup: errors.append(f'setup violations {setup}')
    if hold: errors.append(f'hold violations {hold}')
    values=[('setup',first_slack(t,'Setup Paths Table','Hold Paths Table')),
            ('hold',first_slack(t,'Hold Paths Table','Recovery Paths Table')),
            ('recovery',first_slack(t,'Recovery Paths Table','Removal Paths Table')),
            ('removal',first_slack(t,'Removal Paths Table','Minimum Pulse Width Table'))]
    for name,val in values:
        if val is None or val <= 0: errors.append(f'{name} min slack nonpositive {val}')
    for clock in ('clk27 Base 37.037 27.000','Generated 7.936 126.000','Generated 39.682 25.200'):
        if clock not in t:errors.append('clock missing: '+clock)
    tail=t.partition('Timing Constraints Report:')[2]
    active=len(re.findall(r'\bTC_MAX_DELAY\s+Actived\b',tail))
    if active!=15:errors.append(f'active bounded constraints={active} expected=15')
    rules=[line for line in SDC.read_text(encoding='utf8').splitlines()
           if line.startswith('set_max_delay')]
    if len(rules)!=15:errors.append('local SDC has wrong number of rules')
    for rule in rules:
        if 'TC_MAX_DELAY Actived '+rule not in tail:errors.append('inactive constraint: '+rule)
    start='Setup Analysis Report Report Command:report_exceptions -setup'
    stop='Hold Analysis Report Report Command:report_exceptions -hold'
    excerpt=t.partition(start)[2].partition(stop)[0] if start in t and stop in t else ''
    blocks=re.findall(r'Timing Path Constraint\[\d+\]:\s*(set_max_delay .*?)(?=Timing Path Constraint\[\d+\]:|$)',excerpt,flags=re.S)
    for rule in rules:
        matches=[b for b in blocks if b.startswith(rule+' ')]
        if len(matches)!=1 or 'Path1 Path Summary:' not in matches[0]:
            errors.append('rule without routed sample path: '+rule)
    if log:
        l=log.read_text(encoding='utf8',errors='replace')
        if re.search(r'\b(ERROR|FATAL|TA1124)\b',l):errors.append('Gowin log contains error/TA1124')
        if 'Bitstream generation completed' not in l:errors.append('bitstream completion not confirmed')
    print(f'LAB04_V017_STA_PRELIM: setup={setup}, hold={hold}, slacks={values}, active_max_delay={active}')
    if errors:
        for e in errors: print('  FAIL:',e)
        print('LAB04_V017_STA_PRELIM_FAIL: DO NOT PROGRAM')
        return 1
    print('LAB04_V017_STA_PRELIM_PASS: preliminary only; audit 28-bit CDC coverage before SRAM')
    return 0

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('timing_report_html',type=Path)
    p.add_argument('--log',type=Path)
    a=p.parse_args()
    try:sys.exit(gate(a.timing_report_html,a.log))
    except Exception as exc:
        print('LAB04_V017_STA_PRELIM_ERROR:',exc,file=sys.stderr);sys.exit(2)
