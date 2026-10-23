#!/usr/bin/env python3
"""PiKoSoL v0.1.6a CPU post-route STA gate; does not prove CDC MTBF or board operation.

Check: 27/126/25.2 MHz clocks, no setup/hold violations, positive recovery
and removal, 11 active bounded exceptions (3 original + 8 LED CDC), and
all 8 NEW exceptions independently matching their exact physical endpoints.
"""
import argparse,re,sys
from pathlib import Path
from check_sta_v013 import flat,parse_count,first_slack

REQ=('u_led_cdc/req_sys_s2','u_led_cdc/req_meta_pixel_s1')
BITS=[(f'u_led_cdc/mask_hold_sys_{i}_s0',f'u_led_cdc/mask_pixel_{i}_s0') for i in range(6)]
ACK=('u_led_cdc/ack_pixel_s0','u_led_cdc/ack_meta_sys_s1')
EXPECTED=[REQ,*BITS,ACK]
def command(frm,to):
    return f'set_max_delay -from [get_regs {{{frm}}}] -to [get_regs {{{to}}}] 12.000'

def gate(report,log):
    errors=[]
    t=flat(report)
    for key in ('Numbers of Paths Analyzed','Numbers of Endpoints Analyzed'):
        if parse_count(t,key)<1: errors.append(f'{key} unexpectedly zero')
    setup=parse_count(t,'Numbers of Setup Violated Endpoints')
    hold=parse_count(t,'Numbers of Hold Violated Endpoints')
    recovery=first_slack(t,'Recovery Paths Table','Removal Paths Table')
    removal=first_slack(t,'Removal Paths Table','Minimum Pulse Width Table')
    setup_slack=first_slack(t,'Setup Paths Table','Hold Paths Table')
    hold_slack=first_slack(t,'Hold Paths Table','Recovery Paths Table')
    if setup: errors.append(f'setup violations={setup}')
    if hold: errors.append(f'hold violations={hold}')
    for name,v in [('setup',setup_slack),('hold',hold_slack),('recovery',recovery),('removal',removal)]:
        if v is None or v<=0:errors.append(f'{name} minimum slack not positive: {v}')
    if 'lab04_cpu_video_v016a.sdc' not in t:
        errors.append('incorrect SDC in report (not CPU v016a)')
    for clock in ('clk27 Base 37.037 27.000','Generated 7.936 126.000','Generated 39.682 25.200'):
        if clock not in t:errors.append('clock not recognized: '+clock)
    if 'Timing Constraints Report:' not in t:errors.append('missing timing constraints report')
    tail=t.partition('Timing Constraints Report:')[2]
    count=len(re.findall(r'\bTC_MAX_DELAY\s+Actived\b',tail))
    if count!=11:errors.append(f'active max_delay count={count}, expected=11')
    # All old SVO exceptions as well as the new eight must be active.
    for frm,to in EXPECTED:
        if 'TC_MAX_DELAY Actived '+command(frm,to) not in tail:
            errors.append('constraint absent/inactive: '+frm+' -> '+to)
    start='Setup Analysis Report Report Command:report_exceptions -setup'
    stop='Hold Analysis Report Report Command:report_exceptions -hold'
    setup_except=t.partition(start)[2].partition(stop)[0] if start in t and stop in t else ''
    blocks=re.findall(r'Timing Path Constraint\[\d+\]:\s*(set_max_delay .*?)(?=Timing Path Constraint\[\d+\]:|$)', setup_except,flags=re.S)
    # String-based matching is deliberate: no HTML parsing dependencies.
    old_cmds=[
      'set_max_delay -from [get_regs {u_clock/sys_release_q_2_s1}] -to [get_regs {u_hdmi/u_term/oresetn_q_0_s0}] 12.000',
      'set_max_delay -from [get_regs {u_hdmi/u_term/mem_start_GR_*}] -to [get_pins {u_hdmi/u_term/mem_start_B1_0_s*/DI*}] 12.000',
      'set_max_delay -from [get_regs {u_hdmi/u_term/mem_stop_GR_*}] -to [get_pins {u_hdmi/u_term/mem_stop_B1_0_s*/DI*}] 12.000',
    ]
    for old_cmd in old_cmds:
        if 'TC_MAX_DELAY Actived '+old_cmd not in tail:
            errors.append('original SVO constraint missing: '+old_cmd)
        candidates=[b for b in blocks if b.startswith(old_cmd+' ')]
        if len(candidates)!=1 or 'Path1 Path Summary:' not in candidates[0]:
            errors.append('original SVO constraint does not match physical path: '+old_cmd)
    for frm,to in EXPECTED:
        expected_cmd=command(frm,to)
        matched=[b for b in blocks if b.startswith(expected_cmd+' ')]
        if len(matched)!=1:
            errors.append(f'no unique exception block for {frm} -> {to}')
            continue
        block=matched[0]
        if 'No timing paths to report!' in block[:250] or 'Path1 Path Summary:' not in block:
            errors.append(f'exception matched zero timing paths: {frm} -> {to}')
        if f'From {frm} To {to}' not in block:
            errors.append(f'exception path endpoints mismatch: {frm} -> {to}')
        m=re.search(r'Path1 Path Summary: Slack\s+(-?\d+\.\d+)',block)
        if not m or float(m.group(1))<=0:
            errors.append(f'bounded path slack nonpositive: {frm} -> {to}')
    if log is not None:
        l=log.read_text(encoding='utf-8',errors='replace')
        if re.search(r'\b(ERROR|FATAL|TA1124)\b',l):errors.append('Gowin log error/TA1124')
        if 'Bitstream generation completed' not in l:errors.append('bitstream completion marker missing')
    print(f'LAB04_V016A_STA: setup_viol={setup}, hold_viol={hold}, min_setup={setup_slack}, min_hold={hold_slack}, min_recovery={recovery}, min_removal={removal}, active_max_delay={count}, checked_CDC={len(EXPECTED)}')
    if errors:
        for e in errors:print('  FAIL:',e)
        print('LAB04_V016A_STA_GATE_FAIL: no SRAM programming')
        return 1
    print('LAB04_V016A_STA_REPORT_GATE_PASS: post-route constraints and exceptions verified; RTL/board remain separate gates')
    return 0

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('timing_report_html',type=Path)
    p.add_argument('--log',type=Path)
    a=p.parse_args()
    try:sys.exit(gate(a.timing_report_html,a.log))
    except Exception as e:print('LAB04_V016A_STA_GATE_ERROR:',str(e),file=sys.stderr);sys.exit(2)
