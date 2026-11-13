#!/usr/bin/env python3
"""Conservative Gowin PnR/STA safety gate. Read-only, no FPGA operations."""
import argparse
import hashlib
from html.parser import HTMLParser
import json
from pathlib import Path
import re
import sys

class HTMLText(HTMLParser):
    def __init__(self):
        super().__init__(); self.parts = []
    def handle_data(self, data):
        self.parts.append(data)

def plain(html):
    parser = HTMLText()
    parser.feed(html)
    return ' '.join(' '.join(parser.parts).split())

def first_slack(text, label):
    i = text.find(label + ' Paths Table')
    if i < 0: raise ValueError('Missing '+label+' paths table')
    part = text[i:i+1600]
    found = re.search(r'Path Number Path Slack .*?\b1 ([+-]?\d+(?:\.\d+)?) ', part)
    if not found: raise ValueError('Cannot read '+label+' path slack')
    return float(found.group(1))

def analyze(report_path, log_path, sdc_path, fs_path):
    html = report_path.read_text(encoding='utf-8', errors='replace')
    data = plain(html)
    log = log_path.read_text(encoding='utf-8', errors='replace')
    sdc = sdc_path.read_text(encoding='utf-8')
    def number(pattern, why):
        match = re.search(pattern, data)
        if not match: raise ValueError('Cannot read '+why)
        return float(match.group(1))
    setup_viol = int(number(r'Numbers of Setup Violated Endpoints\s+(\d+)', 'setup violations'))
    hold_viol = int(number(r'Numbers of Hold Violated Endpoints\s+(\d+)', 'hold violations'))
    pix_fmax = number(r'pix_clk\s+74\.250\(MHz\)\s+([\d.]+)\(MHz\)', 'pixel Fmax')
    slacks = {name:first_slack(data,name) for name in ('Setup','Hold','Recovery','Removal')}
    expected = [line.strip() for line in sdc.splitlines() if line.strip().startswith('set_false_path')]
    if len(expected) != 6 or any('get_clocks' in line for line in expected):
        raise ValueError('Unexpected CDC SDC policy; expected 6 first-stage exceptions')
    exceptions = []
    for row in re.findall(r'<tr\b[^>]*>(.*?)</tr>',html,flags=re.I|re.S):
        if 'TC_FALSE_PATH' not in row: continue
        cells = [plain(x) for x in re.findall(r'<t[dh]\b[^>]*>(.*?)</t[dh]>',row,flags=re.I|re.S)]
        if len(cells) >= 3 and cells[0]=='TC_FALSE_PATH':
            exceptions.append({'state':cells[1],'command':cells[2]})
    active = {entry['command'] for entry in exceptions if entry['state']=='Actived'}
    checks={
        'setup_zero':setup_viol==0,
        'hold_zero':hold_viol==0,
        'setup_WNS_nonnegative':slacks['Setup']>=0,
        'hold_WNS_nonnegative':slacks['Hold']>=0,
        'recovery_WNS_nonnegative':slacks['Recovery']>=0,
        'removal_WNS_nonnegative':slacks['Removal']>=0,
        'video_Fmax_at_least_74_25MHz':pix_fmax>=74.25,
        'six_CDC_exceptions_activated':len(exceptions)==6 and active==set(expected),
        'no_BRAM_error':'IF0008' not in log,
        'no_ROM_file_error':'EX3988' not in log,
        'no_synthesis_error':'ERROR (' not in log,
        'PnR_finished':'Placement and routing completed' in log,
        'timing_analysis_finished':'Timing analysis completed' in log,
    }
    out={
        'source':str(report_path),
        'setup_violated_endpoints':setup_viol,
        'hold_violated_endpoints':hold_viol,
        'pixel_fmax_MHz':pix_fmax,
        'worst_slacks_ns':slacks,
        'cdc_exceptions':exceptions,
        'routing_warnings':[w for w in ('PR1014','TA1117') if w in log],
        'checks':checks,
        'decision':'PASS_FOR_IO_REVIEW_NOT_BOARD' if all(checks.values()) else 'FAIL_DO_NOT_PROGRAM',
        'bitstream':None,
    }
    if fs_path is not None and fs_path.is_file():
        out['bitstream']={
            'path':str(fs_path), 'size':fs_path.stat().st_size,
            'sha256':hashlib.sha256(fs_path.read_bytes()).hexdigest()
        }
    return out

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--report',required=True,type=Path)
    ap.add_argument('--log',required=True,type=Path)
    ap.add_argument('--sdc',required=True,type=Path)
    ap.add_argument('--fs',type=Path)
    ap.add_argument('--output',type=Path)
    args=ap.parse_args()
    try:
        result=analyze(args.report,args.log,args.sdc,args.fs)
    except (OSError,ValueError) as exc:
        result={'decision':'FAIL_INCOMPLETE_EVIDENCE','reason':str(exc)}
    message=json.dumps(result,indent=2,ensure_ascii=True)
    print(message)
    if args.output:args.output.write_text(message+'\n',encoding='utf-8')
    return 0 if result['decision'].startswith('PASS_') else 2

if __name__=='__main__':
    sys.exit(main())
