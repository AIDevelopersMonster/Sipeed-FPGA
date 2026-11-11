#!/usr/bin/env python3
"""Check the v0.1.5 candidate topology; NOT a hardware CDC/STA proof."""
from pathlib import Path
import re
import unittest
ROOT=Path(__file__).resolve().parents[1]
CLOCK=(ROOT/'rtl/lab04_video_clocks.v').read_text(encoding='utf-8')
HDMI=(ROOT/'rtl/lab04_svo_hdmi_top.v').read_text(encoding='utf-8')
SDC=(ROOT/'constraints/lab04_video.sdc').read_text(encoding='utf-8')

class LocalSerdesResetContracts(unittest.TestCase):
    def test_no_negedge_release_stage(self):
        self.assertIn('assign serdes_resetn = serdes_release_q[2];',CLOCK)
        self.assertNotIn('serdes_release_f',CLOCK)
        self.assertNotIn('negedge clk_5x_pixel',CLOCK)
    def test_three_lane_preserved_flops(self):
        self.assertRegex(HDMI,r'for \(lane=0; lane<3; lane=lane\+1\)')
        self.assertIn('reg lane_resetn /* synthesis syn_preserve = 1 */',HDMI)
        self.assertIn('serdes_local_resetn[lane] = lane_resetn',HDMI)
        self.assertIn('always @(posedge clk_5x_pixel or negedge serdes_resetn)',HDMI)
    def test_serializer_is_driven_by_lane_local_reset(self):
        self.assertIn('OSER10 u_tmds_serializer [2:0]',HDMI)
        self.assertIn('.PCLK(clk_pixel), .FCLK(clk_5x_pixel), .RESET(~serdes_local_resetn)',HDMI)
        self.assertNotIn('.RESET(~serdes_resetn)',HDMI)
    def test_no_cdc_masking(self):
        commands=[s.split('//')[0].strip() for s in SDC.splitlines()]
        self.assertEqual(sum(s.startswith('set_max_delay ') for s in commands),3)
        self.assertFalse(any(s.startswith(('set_false_path','set_clock_groups')) for s in commands))

if __name__=='__main__': unittest.main(verbosity=2)
