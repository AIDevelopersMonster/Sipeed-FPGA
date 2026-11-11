#!/usr/bin/env python3
"""LAB-04 v0.1.3 static CDC guard; SDC pin-name assumptions are NOT a Gowin STA proof."""
from pathlib import Path
import fnmatch
import re
import unittest
BASE=Path(__file__).resolve().parents[1]

# Exact endpoint spellings from the user's v0.1.1 PnR STA (22 nodes, 11 each).
STA_B1_START=[
    'mem_start_B1_0_s8/DI[0]', 'mem_start_B1_0_s6/DI[2]',
    'mem_start_B1_0_s6/DI[1]', 'mem_start_B1_0_s6/DI[3]',
    'mem_start_B1_0_s4/DI[3]', 'mem_start_B1_0_s4/DI[1]',
    'mem_start_B1_0_s4/DI[2]', 'mem_start_B1_0_s4/DI[0]',
    'mem_start_B1_0_s8/DI[1]', 'mem_start_B1_0_s8/DI[2]',
    'mem_start_B1_0_s6/DI[0]'
]
STA_B1_STOP=[
    'mem_stop_B1_0_s8/DI[1]', 'mem_stop_B1_0_s8/DI[0]',
    'mem_stop_B1_0_s6/DI[3]', 'mem_stop_B1_0_s6/DI[0]',
    'mem_stop_B1_0_s6/DI[1]', 'mem_stop_B1_0_s4/DI[0]',
    'mem_stop_B1_0_s8/DI[2]', 'mem_stop_B1_0_s6/DI[2]',
    'mem_stop_B1_0_s4/DI[3]', 'mem_stop_B1_0_s4/DI[1]',
    'mem_stop_B1_0_s4/DI[2]'
]
PREFIX='u_hdmi/u_term/'
class ConstraintsContract(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.s=(BASE/'constraints/lab04_video.sdc').read_text(encoding='utf-8')
        cls.constraints=[l.strip() for l in cls.s.splitlines() if l.strip().startswith('set_max_delay')]

    def test_three_bounded_paths(self):
        self.assertEqual(len(self.constraints),3)
        self.assertIn('[get_regs {u_clock/sys_release_q_2_s1}]', self.constraints[0])
        self.assertIn('[get_regs {u_hdmi/u_term/oresetn_q_0_s0}]', self.constraints[0])
        for line,ptr in zip(self.constraints[1:],('start','stop')):
            self.assertIn(f'[get_regs {{u_hdmi/u_term/mem_{ptr}_GR_*}}]',line)
            self.assertIn(f'[get_pins {{u_hdmi/u_term/mem_{ptr}_B1_0_s*/DI*}}]',line)
            self.assertNotIn(f'[get_regs {{u_hdmi/u_term/mem_{ptr}_B1_',line)
        for line in self.constraints:
            self.assertTrue(line.endswith('12.000'),line)

    def test_expected_22_sta_endpoints_match(self):
        self.assertEqual(len(STA_B1_START),11)
        self.assertEqual(len(STA_B1_STOP),11)
        self.assertEqual(len(set(STA_B1_START+STA_B1_STOP)),22)
        # Python fnmatch is a MODEL of the wildcard syntax, not Gowin's Tcl parser.
        for endpoints, name in ((STA_B1_START,'start'),(STA_B1_STOP,'stop')):
            pattern=f'{PREFIX}mem_{name}_B1_0_s*/DI*'
            for endpoint in endpoints:
                self.assertTrue(fnmatch.fnmatchcase(PREFIX+endpoint,pattern),endpoint)

    def test_no_global_exceptions(self):
        commands='\n'.join(l.split('//')[0].strip() for l in self.s.splitlines())
        self.assertNotIn('set_false_path',commands)
        self.assertNotIn('set_clock_groups',commands)
        self.assertIn('create_clock -name clk27 -period 37.037',commands)

    def test_3_domain_reset_source_untouched(self):
        s=(BASE/'rtl/lab04_video_clocks.v').read_text()
        for marker in ('sys_release_q[2]','pixel_release_q[2]','serdes_release_q[2]'):
            self.assertIn(marker,s)

if __name__ == '__main__': unittest.main(verbosity=2)
