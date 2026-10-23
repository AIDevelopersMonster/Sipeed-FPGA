#!/usr/bin/env python3
"""LAB-04 v0.1.3 Gowin STA report gate: 3 domains, 3 active max_delay, 0 violations.
This cannot certify metastability MTBF, physical eye margin, HDMI lock or board status.
"""
import argparse,html,re,sys
from pathlib import Path

def flat(path):
    data=path.read_text(encoding='utf-8',errors='replace')
    data=re.sub(r'<(script|style)\b[^>]*>.*?</\1>',' ',data,flags=re.I|re.S)
    data=re.sub(r'<[^>]*>',' ',data)
    return re.sub(r'\s+',' ',html.unescape(data)).strip()

def parse_count(t,key):
    m=re.search(re.escape(key)+r'\s+(\d+)',t)
    if not m: raise ValueError('missing report field: '+key)
    return int(m.group(1))

def first_slack(t,start,stop):
    i=t.find(start)
    if i<0: return None
    j=t.find(stop,i+len(start))
    body=t[i:j if j>i else len(t)]
    m=re.search(r'\b1\s+(-?\d+\.\d+)\s+\S+',body)
    return float(m.group(1)) if m else None

def audit(report,log=None):
    t=flat(report)
    setup=parse_count(t,'Numbers of Setup Violated Endpoints')
    hold=parse_count(t,'Numbers of Hold Violated Endpoints')
    paths=parse_count(t,'Numbers of Paths Analyzed')
    endpoints=parse_count(t,'Numbers of Endpoints Analyzed')
    clocks=all(re.search(p,t) for p in ('clk27 Base 37.037 27.000',
        'Generated 7.936 126.000','Generated 39.682 25.200'))
    tail=t[t.find('Timing Constraints Report:'):] if 'Timing Constraints Report:' in t else ''
    active=len(re.findall(r'TC_MAX_DELAY\s+Actived',tail))
    # Gowin lists original command lines, if it did not report their detail, stop and inspect manually.
    pin_tokens=('u_hdmi/u_term/mem_start_B1_0_s*/DI*',
                'u_hdmi/u_term/mem_stop_B1_0_s*/DI*')
    pin_targets_visible=all(p in tail for p in pin_tokens)
    recovery=first_slack(t,'Recovery Paths Table','Removal Paths Table')
    removal=first_slack(t,'Removal Paths Table','Minimum Pulse Width Table')
    errors=[]
    if setup!=0:errors.append(f'setup={setup}')
    if hold!=0:errors.append(f'hold={hold}')
    if recovery is None or recovery<0:errors.append('recovery unverified or negative')
    if removal is None or removal<0:errors.append('removal unverified or negative')
    if not clocks:errors.append('incomplete 3-clock recognition')
    if active!=3:errors.append(f'active bounded CDC constraints={active}; expected=3')
    if not pin_targets_visible:errors.append('both Gray-pointer target expressions not found in active SDC report')
    if log is not None:
        l=log.read_text(encoding='utf-8',errors='replace')
        if re.search(r'\b(?:ERROR|FATAL)\b|TA1124',l):errors.append('Gowin log contains ERROR/FATAL or TA1124')
        if 'Bitstream generation completed' not in l:errors.append('Gowin log lacks bitstream-completed marker')
    print(f'LAB04_V013_STA_GATE: paths={paths}, endpoints={endpoints}, setup={setup}, hold={hold}, recovery={recovery}, removal={removal}, active_CDC={active}, pins_visible={pin_targets_visible}, clocks={clocks}')
    if errors:
        print('LAB04_V013_STA_GATE_FAIL: '+'; '.join(errors));return 1
    print('LAB04_V013_STA_REPORT_GATE_PASS: report-only check; CDC/BOARD still require manual verification')
    return 0

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('timing_report_html',type=Path)
    p.add_argument('--log',type=Path)
    a=p.parse_args()
    try:sys.exit(audit(a.timing_report_html,a.log))
    except Exception as e:
        print('LAB04_V013_STA_GATE_ERROR:',e,file=sys.stderr);sys.exit(2)
