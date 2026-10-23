#!/usr/bin/env python3
"""LAB04 STA v0.1.1 structural checks. Does NOT imply STA/BOARD PASS."""
import pathlib
import re
import unittest
ROOT = pathlib.Path(__file__).resolve().parent.parent

def src(name): return (ROOT / 'rtl' / name).read_text(encoding='utf8')

class DomainResetContracts(unittest.TestCase):
    def test_async_assert_sync_release_each_domain(self):
        t=src('lab04_video_clocks.v')
        for clk in ['clk27','clk_pixel','clk_5x_pixel']:
            self.assertIn(f'always @(posedge {clk} or negedge pll_run_n)',t)
        for name in ['sys_release_q','pixel_release_q','serdes_release_q']:
            self.assertIn(f'assign ',t)
            self.assertIn(name + " <= 3'b000;", t)
        self.assertIn('assign video_resetn = sys_release_q[2]',t)
        self.assertIn('assign pixel_resetn = pixel_release_q[2]',t)
        self.assertIn('assign serdes_resetn = serdes_release_q[2];',t)
        self.assertNotIn('serdes_release_f',t)
        self.assertNotIn('negedge clk_5x_pixel',t)

    def test_third_party_top_reset_domains(self):
        t=src('lab04_svo_hdmi_top.v')
        for name in ['pixel_resetn','serdes_resetn']:
            self.assertIn('input wire '+name,t)
        self.assertIn('svo_tcard',t)
        self.assertIn('.clk(clk_pixel), .resetn(pixel_resetn)',t)
        self.assertIn('.clk(clk), .oclk(clk_pixel), .resetn(resetn)',t)
        self.assertIn('.RESET(~serdes_local_resetn)',t)
        self.assertIn('reg lane_resetn /* synthesis syn_preserve = 1 */',t)
        self.assertNotIn('clk_pixel_resetn',t)
        self.assertNotIn('.clk(clk_pixel), .resetn(resetn)',t)
        self.assertIn('.in_axis_tready(term_in_tready)',t)
    def test_both_variants_pass_independent_resets(self):
        for top in ['lab04_hdmi_smoke_top.v','lab04_cpu_hdmi_top.v']:
            t=src(top)
            self.assertIn('.video_resetn(video_resetn)',t)
            self.assertIn('.pixel_resetn(pixel_resetn)',t)
            self.assertIn('.serdes_resetn(serdes_resetn)',t)
            self.assertNotIn('.locked(pll_locked)',t)

if __name__=='__main__': unittest.main(verbosity=2)
