#!/usr/bin/env python3
"""Source-level regression gate. Not timing, RTL or physical hardware evidence."""
import hashlib
import importlib.util
import pathlib
import unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
def read(p): return (ROOT/p).read_text(encoding='utf8')

class Lab043Contract(unittest.TestCase):
    def test_gfx_integrated_between_terminal_and_led(self):
        s=read('rtl/lab04_svo_hdmi_top.v')
        self.assertLess(s.index('svo_tcard #'),s.index('lab04_graphics_osd u_graphics'))
        self.assertLess(s.index('lab04_graphics_osd u_graphics'),s.index('svo_overlay #'))
        self.assertLess(s.index('svo_overlay #'),s.index('lab04_led_osd u_led_osd'))
        self.assertLess(s.index('lab04_led_osd u_led_osd'),s.index('svo_enc #'))
        self.assertIn('.RESET(~serdes_local_resetn)',s)
        top=read('rtl/lab04_cpu_hdmi_top.v')
        self.assertIn('lab04_video_cmd_cdc u_video_cdc',top)
        self.assertIn('lab04_cpu_soc u_soc',top)
        self.assertIn('.GFX_ENABLE(1)',top)
        smoke=read('rtl/lab04_hdmi_smoke_top.v')
        self.assertNotIn('lab04_video_cmd_cdc',smoke)
        self.assertIn(".gfx_event_valid(1'b0)",smoke)

    def test_cpu_mmio_decodes_graphics_and_accepted_word_store(self):
        soc=read('rtl/lab04_cpu_soc.v')
        for text in ["24'h200001", "mem_addr[31:14] == 18'b0", '.word_addr(mem_addr[13:2])',
                     "(mem_wstrb == 4'hf)", 'video_wr_ready', 'video_shadow[vid_idx]',
                     'else if (is_vmmio)']:
            self.assertIn(text,soc)
        self.assertIn('if (video_wr_ready)',soc)

    def test_mailbox_order_and_bundled_data(self):
        cdc=read('rtl/lab04_video_cmd_cdc.v')
        for text in ['packet_hold_sys <= {wr_index, wr_value};','if (wr_valid && wr_ready)',
                     'req_meta_pixel <= req_sys;', 'req_sync_pixel <= req_meta_pixel;',
                     'event_value <= packet_hold_sys[23:0];', 'ack_pixel <= req_sync_pixel;',
                     'assign wr_ready = (req_sys == ack_sync_sys);']:
            self.assertIn(text,cdc)

    def test_graphics_requires_explicit_commit(self):
        gfx=read('rtl/lab04_graphics_osd.v')
        for text in ["4'd15: commit_pending <= 1'b1;",'if (commit_pending) begin',
                     'ax_frame <= ax_stage;', 'bx_frame <= bx_stage;',
                     'assign s_axis_tready = m_axis_tready;',
                     'assign m_axis_tvalid = s_axis_tvalid;',
                     'assign m_axis_tuser = s_axis_tuser;',
                     'paint_b ? bc_frame : paint_a ? ac_frame : s_axis_tdata']:
            self.assertIn(text,gfx)

    def test_video_cdc_sdc_is_annotated_not_broadly_disabled(self):
        base=read('constraints/lab04_cpu_video_v016a.sdc')
        new=read('constraints/lab04_cpu_video_v017.sdc')
        self.assertTrue(new.startswith(base))
        body='\n'.join(l for l in new.splitlines() if not l.startswith('//'))
        self.assertNotIn('set_false_path',body)
        self.assertNotIn('set_clock_groups',body)
        self.assertEqual(sum(l.startswith('set_max_delay') for l in new.splitlines()),15)
        for name in ['req_meta_pixel','ack_meta_sys','event_index','event_value']:
            self.assertIn(name,new)
        self.assertIn('add_file lab04/constraints/lab04_cpu_video_v018b.sdc',read('build_scripts/gowin_lab04_cpu.tcl'))
        self.assertIn('add_file lab04/constraints/lab04_video.sdc',read('build_scripts/gowin_lab04_smoke.tcl'))

    def test_firmware_ascii_shared_and_legacy_protocol(self):
        source=read('firmware/lab04_boot.S')
        for cmd in ['count0:','count6:','one1:','one6:','query:','panel:',
                    'move_up:','move_left:','move_down:','move_right:',
                    'color_red:','color_green:','color_blue:','color_white:',
                    'sw t4, 60(s2)','panel_bits:']:
            self.assertIn(cmd,source)
        self.assertNotIn('\\u001b',source)
        self.assertIn('slli',read('tools/build_rom.py'))
        self.assertIn('CAPACITY = 4096',read('tools/build_rom.py'))
        self.assertIn('baud',read('tools/console_lab04.py'))

if __name__=='__main__':unittest.main(verbosity=2)
