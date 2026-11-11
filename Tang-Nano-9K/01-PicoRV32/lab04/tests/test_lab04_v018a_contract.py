import unittest
from pathlib import Path
R=Path(__file__).resolve().parents[1]
class Contract(unittest.TestCase):
 def test_handshake(self):
  s=(R/'rtl/lab04_ui_background.v').read_text();self.assertIn('assign s_axis_tready=m_axis_tready',s);self.assertIn('if (advance)',s);self.assertIn('s_axis_tuser[0]',s)
 def test_cpu_only(self):
  self.assertIn('.UI_SHELL_ENABLE(1)',(R/'rtl/lab04_cpu_hdmi_top.v').read_text());self.assertIn('lab04_ui_background.v',(R/'build_scripts/gowin_lab04_cpu.tcl').read_text())
 def test_phy_preserved(self):
  s=(R/'rtl/lab04_svo_hdmi_top.v').read_text();self.assertIn('OSER10',s);self.assertIn('g_serdes_reset_lane',s)
if __name__=='__main__':unittest.main()
