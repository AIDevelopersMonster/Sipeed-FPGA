#!/usr/bin/env python3
"""Static source contracts for LAB-04: no vendor tools or local machine access."""
from __future__ import annotations

import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
VENDOR_SHA = 'c3b795799f23de91982be52db4273a8eea100cdb'


class StructureTests(unittest.TestCase):
    def read(self, rel):
        return (ROOT / rel).read_text(encoding='utf-8')

    def test_no_lab03_file_paths_modified_by_build_tools(self):
        build = self.read('tools/build_lab04.ps1')
        self.assertIn("$job = Join-Path $lab", build)
        self.assertIn("Push-Location $work", build)
        self.assertNotIn('assemble_lab03.py', build)
        self.assertNotIn('Reset-Hard', build)
        self.assertNotIn('git clean', build)
        for name in ('lab04_hdmi_smoke_nano9k', 'picorv32_lab04_hdmi_nano9k'):
            self.assertIn(name, build)

    def test_reference_pinned(self):
        fetch = self.read('tools/fetch_picotiny.ps1')
        self.assertIn(VENDOR_SHA, fetch)
        self.assertIn('SOURCE_PIN.txt', fetch)
        self.assertIn('SOURCE_SHA256.txt', fetch)
        self.assertIn('picotiny_ref', fetch)

    def test_tcl_sources_are_known(self):
        known = {'svo_defines.vh', 'svo_enc.v', 'svo_openldi.v',
                 'svo_tcard.v', 'svo_term.v', 'svo_tmds.v', 'svo_utils.v', 'svo_vdma.v'}
        for variant in ('smoke', 'cpu'):
            tcl = self.read(f'build_scripts/gowin_lab04_{variant}.tcl')
            actual = set(re.findall(r'add_file vendor/picotiny_ref/hw/hdmi/(svo_[^\s]+)', tcl))
            self.assertEqual(actual, known)
            self.assertIn('Gowin', self.read('rtl/lab04_video_clocks.v'))
            self.assertIn('run all', tcl)

    def test_hdmi_board_pin_contract(self):
        expected = {'clk':'52', 'reset_n':'3', 'tmds_clk_p':'69,68',
                    'tmds_d_p[0]':'71,70', 'tmds_d_p[1]':'73,72',
                    'tmds_d_p[2]':'75,74',
                    'led_n[0]':'10', 'led_n[1]':'11', 'led_n[2]':'13',
                    'led_n[3]':'14', 'led_n[4]':'15', 'led_n[5]':'16'}
        for v in ('smoke','cpu'):
            cst = self.read(f'constraints/lab04_{"hdmi_smoke" if v=="smoke" else "cpu_hdmi"}.cst')
            records = dict(re.findall(r'IO_LOC\s+"([^"]+)"\s+([0-9,]+);', cst))
            for name,pins in expected.items():
                self.assertEqual(records.get(name),pins)
            values = [pin for pair in records.values() for pin in pair.split(',')]
            self.assertEqual(len(values),len(set(values)), 'Duplicate physical pin in IO_LOC list')
            if v == 'cpu':
                self.assertEqual(records['uart_tx'],'17')
                self.assertEqual(records['uart_rx'],'18')
            else:
                self.assertNotIn('uart_rx', records)

    def test_video_only_smoke_and_real_cpu_separation(self):
        smoke = self.read('rtl/lab04_hdmi_smoke_top.v')
        combo = self.read('rtl/lab04_cpu_hdmi_top.v')
        self.assertNotRegex(smoke, r'\bpicorv32\s+#?\(')
        self.assertIn('lab04_svo_hdmi_top u_hdmi', smoke)
        self.assertIn('lab04_cpu_soc u_soc', combo)
        self.assertIn('lab04_uart_tty_bridge', combo)
        self.assertIn('lab04_svo_hdmi_top #(.LED_OSD_ENABLE(1), .GFX_ENABLE(1), .UI_SHELL_ENABLE(1), .CONSOLE_ENABLE(1)) u_hdmi', combo)

    def test_ascii_input_has_its_own_ready_handshake(self):
        adapted = self.read('rtl/lab04_svo_hdmi_top.v')
        self.assertIn('output wire term_in_tready', adapted)
        self.assertIn('.in_axis_tready(term_in_tready)', adapted)
        self.assertIn('.out_axis_tready(term_out_tready)', adapted)
        self.assertIn('.over_axis_tready(term_out_tready)', adapted)
        self.assertIn('.term_in_tready(video_byte_ready)', self.read('rtl/lab04_cpu_hdmi_top.v'))
        self.assertIn('.term_in_tready(banner_ready)', self.read('rtl/lab04_hdmi_smoke_top.v'))


if __name__ == '__main__':
    unittest.main(verbosity=2)
