#!/usr/bin/env python3
"""v0.1.6a CPU-only SDC contract. This is NOT Gowin STA proof."""
from pathlib import Path
import re,unittest
ROOT = Path(__file__).resolve().parent.parent
REQ = 'set_max_delay -from [get_regs {u_led_cdc/req_sys_s2}] -to [get_regs {u_led_cdc/req_meta_pixel_s1}] 12.000'
ACK = 'set_max_delay -from [get_regs {u_led_cdc/ack_pixel_s0}] -to [get_regs {u_led_cdc/ack_meta_sys_s1}] 12.000'
BITS = [f'set_max_delay -from [get_regs {{u_led_cdc/mask_hold_sys_{i}_s0}}] -to [get_regs {{u_led_cdc/mask_pixel_{i}_s0}}] 12.000' for i in range(6)]
class CpuCdcTiming(unittest.TestCase):
    def test_original_smoke_sdc_unchanged(self):
        original=(ROOT/'constraints/lab04_video.sdc').read_text(encoding='utf-8')
        cpu=(ROOT/'constraints/lab04_cpu_video_v016a.sdc').read_text(encoding='utf-8')
        self.assertTrue(cpu.startswith(original))
        self.assertEqual(len([x for x in original.splitlines() if x.startswith('set_max_delay')]),3)
        self.assertEqual(len([x for x in cpu.splitlines() if x.startswith('set_max_delay')]),11)
        for exact in [REQ,*BITS,ACK]: self.assertEqual(cpu.splitlines().count(exact),1,exact)
        self.assertNotIn('set_false_path', '\n'.join(x for x in cpu.splitlines() if not x.strip().startswith('//')))
        self.assertNotIn('set_clock_groups', '\n'.join(x for x in cpu.splitlines() if not x.strip().startswith('//')))
    def test_only_cpu_uses_new_sdc(self):
        cpu=(ROOT/'build_scripts/gowin_lab04_cpu.tcl').read_text(encoding='utf-8')
        smoke=(ROOT/'build_scripts/gowin_lab04_smoke.tcl').read_text(encoding='utf-8')
        cpu_sdc=re.findall(r'^add_file (\S+\.sdc)$',cpu,re.M)
        smoke_sdc=re.findall(r'^add_file (\S+\.sdc)$',smoke,re.M)
        self.assertEqual(cpu_sdc,['lab04/constraints/lab04_cpu_video_v018b.sdc'])
        self.assertEqual(smoke_sdc,['lab04/constraints/lab04_video.sdc'])
    def test_exact_endpoints_in_prior_sta(self):
        # Verified against user's v0.1.6 setup paths on 22 Oct 2026.
        self.assertEqual(len(BITS),6)
        for i in range(6):
            self.assertIn(f'mask_hold_sys_{i}_s0',BITS[i]);self.assertIn(f'mask_pixel_{i}_s0',BITS[i])
if __name__=='__main__': unittest.main(verbosity=2)
