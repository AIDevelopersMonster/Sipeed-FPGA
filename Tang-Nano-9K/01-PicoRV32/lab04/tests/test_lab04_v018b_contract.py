#!/usr/bin/env python3
"""v0.1.8b structural regression checks. Not equivalent to STA/board tests."""
from pathlib import Path
import re,unittest
R=Path(__file__).resolve().parents[1]
def txt(name):return (R/name).read_text(encoding='utf8')
class ConsoleContract(unittest.TestCase):
 def test_new_cpu_console_and_legacy_smoke(self):
  cpu=txt('rtl/lab04_cpu_hdmi_top.v');hdmi=txt('rtl/lab04_svo_hdmi_top.v')
  smoke=txt('rtl/lab04_hdmi_smoke_top.v')
  self.assertIn('.CONSOLE_ENABLE(1)',cpu)
  self.assertNotIn('CONSOLE_ENABLE(1)',smoke)
  for item in ('g_legacy_term','g_addressable_console','svo_overlay #',
               'lab04_graphics_osd u_graphics','OSER10','g_serdes_reset_lane'):
   self.assertIn(item,hdmi)
 def test_pixel_ram_and_single_byte_cdc(self):
  osd=txt('rtl/lab04_console_osd.v')
  cdc=txt('rtl/lab04_tty_byte_cdc.v')
  for v in ('log_mem [0:LOG_SIZE-1]','LOG_COLS = 76','LOG_SIZE = 2432',
            'if (s_axis_tuser[0])','s_axis_tready = a_ready',
            'pixel_accept(!clearing)','gfx_event_index','shown_led'):
   self.assertIn(v,osd)
  for v in ('char_hold_sys <= char_data','req_sync_pixel <= req_meta_pixel',
            'ack_sync_sys <= ack_meta_sys','event_byte <= char_hold_sys',
            'assign char_ready = (req_sys == ack_sync_sys)'):
   self.assertIn(v,cdc)
  self.assertNotIn('svo_term #',osd)
 def test_build_and_constraints(self):
  tcl=txt('build_scripts/gowin_lab04_cpu.tcl')
  for f in ('lab04_console_osd.v','lab04_tty_byte_cdc.v','lab04_cpu_video_v018b.sdc'):
   self.assertIn(f,tcl)
  cdc=txt('constraints/lab04_cpu_video_v018b.sdc')
  self.assertEqual(15,len(re.findall(r'^set_max_delay',cdc,re.M)))
  self.assertNotIn('set_false_path',cdc)
  self.assertIn('max_paths 96',cdc)
 def test_font_rom_and_static_area(self):
  osd=txt('rtl/lab04_console_osd.v')
  self.assertNotIn('function [95:0] glyph_rom',osd)
  self.assertIn('syn_romstyle = "block_rom"',osd)
  self.assertIn('syn_ramstyle = "block_ram"',osd)
  self.assertIn('font_row_b <= font_mem[font_addr]',osd)
  self.assertIn('log_char_a <= log_mem[log_addr]',osd)
  self.assertIn("text_row==6'd39",osd)
  mem=[int(x,16) for x in txt('rtl/lab04_font_8x12.hex').splitlines()]
  self.assertEqual(2048,len(mem))
  self.assertEqual([0,0x30,0x38,0x28],mem[0x41*16:0x41*16+4])
  self.assertEqual([0,0x78,0x4c,0x44],mem[0x50*16:0x50*16+4])
  self.assertIn("9'd352",osd);self.assertIn("9'd400",osd)
  self.assertIn('static_char=8\'h50',osd)
if __name__=='__main__':unittest.main(verbosity=2)
