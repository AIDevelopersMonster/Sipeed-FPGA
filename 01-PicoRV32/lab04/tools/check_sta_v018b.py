#!/usr/bin/env python3
"""v0.1.8b post-route gate: 28 graphics + 8 TTY bundled CDC bit paths.
No board programming unless all constraints are active and both byte and
28-bit graphics CDC have real positive-slack routed endpoints.
"""
from pathlib import Path
import argparse, html, re, sys

def flatten(p):
 s=p.read_text(encoding='utf8',errors='replace')
 s=re.sub(r'<(script|style)\b[^>]*>.*?</\1>',' ',s,flags=re.I|re.S)
 return re.sub(r'\s+',' ',html.unescape(re.sub(r'<[^>]*>',' ',s))).strip()

def cnt(t,key):
 m=re.search(re.escape(key)+r'\s+(\d+)',t)
 if not m:raise ValueError('missing '+key)
 return int(m.group(1))

def min_slack(t,a,b):
 part=t.partition(a)[2].partition(b)[0]
 m=re.search(r'\b1\s+(-?\d+(?:\.\d+)?)\s+\S+',part)
 return float(m.group(1)) if m else None

def block(seg,group):
 m=re.search(r'Timing Path Constraint\['+str(group)+r'\]:\s*set_max_delay',seg)
 if not m:return ''
 remaining=seg[m.end():]
 x=re.search(r'Timing Path Constraint\[\d+\]:|Hold Analysis Report Report Command:report_exceptions',remaining)
 return remaining[:x.start()] if x else remaining

def bit_paths(part,src,dst):
 rx=(r'Path\d+\s+Path Summary:\s+Slack\s+(-?\d+(?:\.\d+)?)\b'
     r'(?:(?!Path\d+\s+Path Summary:).)*?\bFrom\s+\S*?'+src+r'_(\d+)_s\d+'
     r'\s+To\s+\S*?'+dst+r'_(\d+)_s\d+')
 return [(int(a),int(b),float(slack)) for slack,a,b in re.findall(rx,part,flags=re.S)]

def handshake(part,src,dst):
 rx=(r'Path\d+\s+Path Summary:\s+Slack\s+(-?\d+(?:\.\d+)?)\b'
     r'(?:(?!Path\d+\s+Path Summary:).)*?\bFrom\s+\S*?'+src+r'\w*'
     r'\s+To\s+\S*?'+dst+r'\w*')
 return [float(i) for i in re.findall(rx,part,flags=re.S)]

def run(report,log):
 t=flatten(report);errors=[]
 for f in ('lab04_cpu_video_v018b.sdc',):
  if f not in t:errors.append('SDC not in report: '+f)
 if cnt(t,'Numbers of Paths Analyzed')<1:errors.append('no timing paths analyzed')
 if cnt(t,'Numbers of Setup Violated Endpoints') or cnt(t,'Numbers of Hold Violated Endpoints'):
  errors.append('setup or hold violations')
 slacks={k:min_slack(t,a,b) for k,a,b in [
  ('setup','Setup Paths Table','Hold Paths Table'),
  ('hold','Hold Paths Table','Recovery Paths Table'),
  ('recovery','Recovery Paths Table','Removal Paths Table'),
  ('removal','Removal Paths Table','Minimum Pulse Width Table')]}
 for k,v in slacks.items():
  if v is None or v<=0:errors.append('missing/nonpositive '+k+': '+str(v))
 tail=t.partition('Timing Constraints Report:')[2]
 active=len(re.findall(r'\bTC_MAX_DELAY\s+Actived\b',tail))
 if active!=15:errors.append('active max-delay rules !=15: '+str(active))
 sections=re.split(r'(?=Setup Analysis Report Report Command:report_exceptions\s+-setup\b)',
                   t.partition('Timing Exceptions Report:')[2].partition('Timing Constraints Report:')[0])
 candidates=[]
 for seg in sections:
  if not seg.startswith('Setup Analysis Report Report Command:report_exceptions -setup'):continue
  i=bit_paths(block(seg,11),'u_video_cdc/packet_hold_sys','u_video_cdc/event_index')
  v=bit_paths(block(seg,12),'u_video_cdc/packet_hold_sys','u_video_cdc/event_value')
  b=bit_paths(block(seg,15),'u_tty_cdc/char_hold_sys','u_tty_cdc/event_byte')
  r=handshake(block(seg,13),'u_tty_cdc/req_sys','u_tty_cdc/req_meta_pixel')
  a=handshake(block(seg,14),'u_tty_cdc/ack_pixel','u_tty_cdc/ack_meta_sys')
  candidates.append((i,v,b,r,a))
 if not candidates: errors.append('no setup exception route tables');i=v=b=r=a=[]
 else:i,v,b,r,a=max(candidates,key=lambda v:len(v[0])+len(v[1])+len(v[2])+len(v[3])+len(v[4]))
 def check(label,paths,expected):
  observed={(x,y) for x,y,_ in paths}
  if observed!=expected:errors.append(label+' missing='+str(sorted(expected-observed))+' unexpected='+str(sorted(observed-expected)))
  if any(s<=0 for _,_,s in paths):errors.append(label+' nonpositive routed slack')
 check('graphics_index',i,{(24+x,x) for x in range(4)})
 check('graphics_value',v,{(x,x) for x in range(24)})
 check('tty_char',b,{(x,x) for x in range(8)})
 if not r or not a:errors.append('TTY req/ack physical routes not shown')
 if any(s<=0 for s in r+a):errors.append('TTY req/ack negative routed slack')
 if log:
  l=log.read_text(encoding='utf8',errors='replace')
  if re.search(r'\b(?:ERROR|FATAL|TA1124)\b',l):errors.append('Gowin log ERROR/FATAL/TA1124')
  if 'Bitstream generation completed' not in l:errors.append('no confirmed bitstream completion')
 print('CDC PHYSICAL ROUTES: graphics index=%d/4 value=%d/24 tty=%d/8 req=%d ack=%d'%(len(i),len(v),len(b),len(r),len(a)))
 print('STA: active=%d/15 minimum_slacks=%s'%(active,slacks))
 if errors:
  for x in errors:print('BLOCKER:',x)
  print('LAB04_V018B_STA_GATE_FAIL: DO NOT PROGRAM');return 1
 print('LAB04_V018B_STA_GATE_PASS: all 36 bundled CDC data bits and toggles routed; BOARD PENDING');return 0

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('timing_html',type=Path);p.add_argument('--log',type=Path)
 a=p.parse_args()
 try:sys.exit(run(a.timing_html,a.log))
 except Exception as e:print('LAB04_V018B_AUDITOR_ERROR:',e,file=sys.stderr);sys.exit(2)
