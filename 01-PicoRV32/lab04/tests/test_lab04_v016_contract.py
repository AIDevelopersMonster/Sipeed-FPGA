#!/usr/bin/env python3
"""PiKoSoL v0.1.6 static design contracts (not a replacement for RTL/STA)."""
from __future__ import annotations
import hashlib
import pathlib
import unittest

BASE = pathlib.Path(__file__).resolve().parents[1]


def source(path):
    return (BASE / path).read_text(encoding='utf-8')


class LedOsdContract(unittest.TestCase):
    def test_cpu_mask_is_uninverted_actual_mmio(self):
        soc = source('rtl/lab04_cpu_soc.v')
        self.assertIn('assign led_mask_sys = leds;', soc)
        self.assertIn('assign led_n = ~leds;', soc)
        self.assertIn("if ((|mem_wstrb) && mem_wstrb[0]) leds <= mem_wdata[5:0];", soc)

    def test_cdc_is_bundled_handshake_not_unsynchronized_bus(self):
        cdc = source('rtl/lab04_led_mask_cdc.v')
        self.assertIn('if ((ack_sync_sys == req_sys) && (mask_hold_sys != mask_sys))', cdc)
        self.assertIn('if (req_sync_pixel != ack_pixel)', cdc)
        self.assertIn('mask_pixel <= mask_hold_sys;', cdc)
        for f in ('ack_meta_sys','ack_sync_sys','req_meta_pixel','req_sync_pixel'):
            self.assertIn('reg ' + f + ';', cdc)

    def test_osd_is_pixel_side_synchronous_and_handshake_transparent(self):
        osd = source('rtl/lab04_led_osd.v')
        self.assertIn('assign s_axis_tready = m_axis_tready;', osd)
        self.assertIn('assign m_axis_tvalid = s_axis_tvalid;', osd)
        self.assertIn('assign m_axis_tuser = s_axis_tuser;', osd)
        self.assertIn('wire fire = s_axis_tvalid && s_axis_tready;', osd)
        self.assertIn('frame_mask <= mask_pixel;', osd)
        self.assertIn('if (s_axis_tuser[0])', osd)
        for n in range(6):
            self.assertIn(f'frame_mask[{n}]', osd)

    def test_cpu_pins_and_hdmi_pipeline(self):
        top = source('rtl/lab04_cpu_hdmi_top.v')
        hdmi = source('rtl/lab04_svo_hdmi_top.v')
        self.assertIn('.led_mask_sys(led_mask_sys)', top)
        self.assertIn('lab04_led_mask_cdc u_led_cdc', top)
        self.assertIn('.mask_pixel(led_mask_pixel)', top)
        self.assertIn('lab04_svo_hdmi_top #(.LED_OSD_ENABLE(1), .GFX_ENABLE(1), .UI_SHELL_ENABLE(1), .CONSOLE_ENABLE(1)) u_hdmi', top)
        self.assertLess(hdmi.index('svo_overlay #'), hdmi.index('lab04_led_osd u_led_osd'))
        self.assertLess(hdmi.index('lab04_led_osd u_led_osd'), hdmi.index('svo_enc #'))
        self.assertIn('OSER10 u_tmds_serializer [2:0]', hdmi)
        self.assertIn('.RESET(~serdes_local_resetn)', hdmi)
        self.assertIn(".led_mask_pixel(6'b000000)", source('rtl/lab04_hdmi_smoke_top.v'))

    def test_both_gowin_variants_have_osd_and_cpu_has_cdc(self):
        for mode in ('cpu','smoke'):
            tcl = source(f'build_scripts/gowin_lab04_{mode}.tcl')
            self.assertIn('add_file lab04/rtl/lab04_led_osd.v', tcl)
            self.assertEqual(tcl.count('add_file lab04/rtl/lab04_led_osd.v'),1)
            if mode == 'cpu':
                self.assertIn('add_file lab04/rtl/lab04_led_mask_cdc.v',tcl)
            else:
                self.assertNotIn('lab04_led_mask_cdc.v',tcl)

    def test_golden_unchanged_clock_and_sdc(self):
        # Legacy clock/SDC hashes: unchanged from supplied v0.1.5 archive.
        originals = {
            'rtl/lab04_video_clocks.v': '02d7022c3a4e30b986e13b9281b1144a350cd3082f88990e2f871f90a2003168',
            'constraints/lab04_video.sdc': '81a63dc1c098c75a3ebe1d511a204e14d5a6901d7be710f34c4e56051bdd8fee',
                                                        }
        for rel, sha in originals.items():
            self.assertEqual(hashlib.sha256((BASE/rel).read_bytes()).hexdigest(), sha, rel)


if __name__ == '__main__':
    unittest.main(verbosity=2)
