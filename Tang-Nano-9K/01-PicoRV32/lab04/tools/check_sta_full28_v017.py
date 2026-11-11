#!/usr/bin/env python3
"""PiKoSoL LAB-04.3 independent post-route 28-bit CDC audit.

Reads Gowin timing HTML. Does NOT run synthesis, change RTL/SDC or program FPGA.
A standard report_exceptions -max_paths 5 is intentionally insufficient.
Requires a verbose report with distinct routed index/value paths for all 28 bits.
"""
import argparse, html, re, sys
from pathlib import Path


def flatten(p: Path) -> str:
    text = p.read_text(encoding='utf-8', errors='replace')
    text = re.sub(r'<(script|style)\b[^>]*>.*?</\1>', ' ', text, flags=re.I|re.S)
    text = re.sub(r'<[^>]*>', ' ', text)
    return re.sub(r'\s+', ' ', html.unescape(text)).strip()


def extract_count(data, label):
    found = re.search(re.escape(label)+r'\s+(\d+)', data)
    if not found:
        raise ValueError('missing timing summary: '+label)
    return int(found.group(1))


def lowest_slack(text, start, stop):
    a=text.find(start)
    b=text.find(stop,a+len(start)) if a>=0 else -1
    part=text[a:b] if a>=0 and b>=0 else ''
    m=re.search(r'\b1\s+(-?\d+(?:\.\d+)?)\s+\S+',part)
    return float(m.group(1)) if m else None


def group_paths(text, group):
    """Yield tuples (source bit, target bit, slack) in exception group."""
    start_pattern=r'Timing Path Constraint\['+str(group)+r'\]:\s*set_max_delay\b'
    match=re.search(start_pattern, text)
    if not match:
        return []
    remaining=text[match.end():]
    stop=re.search(r'Timing Path Constraint\[\d+\]:|Hold Analysis Report Report Command:report_exceptions|Recovery Analysis Report Report Command:report_exceptions|Removal Analysis Report Report Command:report_exceptions',remaining)
    body=remaining[:stop.start()] if stop else remaining
    target=('index' if group==14 else 'value')
    pat=(r'Path\d+\s+Path Summary:\s+Slack\s+(-?\d+(?:\.\d+)?)\b'
         r'(?:(?!Path\d+\s+Path Summary:).)*?\bFrom\s+u_video_cdc/packet_hold_sys_(\d+)_s\d+'
         r'\s+To\s+u_video_cdc/event_'+target+r'_(\d+)_s\d+')
    return [(int(src),int(dst),float(slack)) for slack,src,dst in re.findall(pat,body,flags=re.S)]


def run(timing: Path, log: Path | None) -> int:
    t=flatten(timing)
    errors=[]
    if 'lab04_cpu_video_v017.sdc' not in t:
        errors.append('report does not name v0.1.7 SDC')
    for name in ('Numbers of Paths Analyzed','Numbers of Endpoints Analyzed'):
        if extract_count(t,name)<1:errors.append('no '+name)
    setup=extract_count(t,'Numbers of Setup Violated Endpoints')
    hold=extract_count(t,'Numbers of Hold Violated Endpoints')
    if setup!=0:errors.append(f'setup violations: {setup}')
    if hold!=0:errors.append(f'hold violations: {hold}')
    slacks={key:lowest_slack(t,a,b) for key,a,b in (
       ('setup','Setup Paths Table','Hold Paths Table'),
       ('hold','Hold Paths Table','Recovery Paths Table'),
       ('recovery','Recovery Paths Table','Removal Paths Table'),
       ('removal','Removal Paths Table','Minimum Pulse Width Table'))}
    for key,value in slacks.items():
        if value is None or value<=0:errors.append(f'{key} minimum slack is missing/non-positive: {value}')
    tail=t.partition('Timing Constraints Report:')[2]
    active=len(re.findall(r'\bTC_MAX_DELAY\s+Actived\b',tail))
    if active!=15:errors.append(f'active max-delay rules {active} != 15')
    for clk in ('clk27 Base 37.037 27.000','Generated 7.936 126.000','Generated 39.682 25.200'):
        if clk not in t:errors.append('missing clock '+clk)
    pathsection=t.partition('Timing Exceptions Report:')[2].partition('Timing Constraints Report:')[0]
    candidates=re.split(r'(?=Setup Analysis Report Report Command:report_exceptions\s+-setup\b)',pathsection)
    results=[]
    for segment in candidates:
        if not segment.startswith('Setup Analysis Report Report Command:report_exceptions -setup'):
            continue
        ix=group_paths(segment,14)
        val=group_paths(segment,15)
        results.append((ix,val,segment[:140]))
    if not results:
        errors.append('setup exception report groups not found')
        index=[]; value=[]
    else:
        index,value,_=max(results,key=lambda item:len(item[0])+len(item[1]))
    print('GRAPHICS CDC routed samples: index=%d/4, value=%d/24' % (len(index),len(value)))
    if index:
        print('  index bits:',sorted(set(dst for src,dst,_ in index)))
    if value:
        print('  value bits:',sorted(set(dst for src,dst,_ in value)))
    expected_index={(24+b,b) for b in range(4)}
    expected_value={(b,b) for b in range(24)}
    have_index={(src,dst) for src,dst,_ in index}
    have_value={(src,dst) for src,dst,_ in value}
    missing_index=sorted(expected_index-have_index)
    missing_value=sorted(expected_value-have_value)
    unexpected_index=sorted(have_index-expected_index)
    unexpected_value=sorted(have_value-expected_value)
    if missing_index:errors.append(f'index missing bit-path pairs: {missing_index}')
    if missing_value:errors.append(f'value missing bit-path pairs: {missing_value}')
    if unexpected_index:errors.append(f'index unexpected bit-path pairs: {unexpected_index}')
    if unexpected_value:errors.append(f'value unexpected bit-path pairs: {unexpected_value}')
    if any(slack<=0 for _,_,slack in index+value):
        errors.append('graphics CDC sample has non-positive constrained slack')
    if log:
        data=log.read_text(encoding='utf8',errors='replace')
        if re.search(r'\b(?:ERROR|FATAL)\b|TA1124',data):
            errors.append('Gowin log ERROR/FATAL/TA1124')
        if 'Bitstream generation completed' not in data:
            errors.append('no Gowin bitstream completion confirmation')
    print('STA summary: setup_viol=%d hold_viol=%d slacks=%s active_max_delay=%d' % (setup,hold,slacks,active))
    if errors:
        for problem in errors:print('  BLOCKER:',problem)
        print('LAB04_V017_FULL28_GATE_FAIL: DO NOT PROGRAM')
        return 1
    print('LAB04_V017_FULL28_STA_PASS: all 28 unique routed graphic CDC bit paths bounded; UART/BOARD untested')
    return 0

if __name__ == '__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('timing_html',type=Path)
    parser.add_argument('--log',type=Path)
    args=parser.parse_args()
    try:sys.exit(run(args.timing_html,args.log))
    except Exception as exc:
        print('LAB04_V017_FULL28_ERROR: '+str(exc),file=sys.stderr)
        sys.exit(2)
