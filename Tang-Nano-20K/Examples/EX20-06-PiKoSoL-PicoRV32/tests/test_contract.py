"""Static source-contract tests. Does NOT claim HDL simulation or BOARD PASS."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Contract(unittest.TestCase):
    def test_native_resolution_without_640_crop(self):
        s = (ROOT / 'rtl/pikosol20k_top.v').read_text()
        self.assertIn("12'd1540", s)
        self.assertIn("12'd745", s)
        self.assertIn('pikosol20k_renderer', s)
        self.assertNotIn('canvas_valid', s)

    def test_eight_objects(self):
        s = (ROOT / 'rtl/pikosol20k_renderer.v').read_text()
        self.assertIn('obj<8', s)
        self.assertIn('gfx_index[5:3]', s)
        self.assertIn('gfx_index == 6\'d15', s)
        self.assertIn('glyph_y = py % 12', s)

    def test_native_terminal_and_led(self):
        s = (ROOT / 'rtl/pikosol20k_renderer.v').read_text()
        self.assertIn('localparam integer COLS = 160;', s)
        self.assertIn('localparam integer RING_ROWS = 64;', s)
        self.assertIn('py >= 10\'d624', s)
        self.assertIn('leds[led_idx]', s)

    def test_only_sram_build_script(self):
        s = (ROOT / 'build.ps1').read_text()
        self.assertNotIn(' --flash', s)
        self.assertNotIn(' --run ', s)
        self.assertIn('-StageOnly', s.replace('[switch]$StageOnly', '-StageOnly'))

    def test_pin_nonoverlap(self):
        c = (ROOT / 'constraints/pikosol20k.cst').read_text()
        pins = {}
        for sig, raw in re.findall(r'IO_LOC\s+"([^"]+)"\s+([\d,]+);', c):
            for pin in raw.split(','):
                self.assertNotIn(pin, pins, f'conflict: pin {pin}: {pins.get(pin)} vs {sig}')
                pins[pin] = sig
        self.assertEqual(6, sum('led_n[' in x for x in pins.values()))
        self.assertEqual(18, len(pins))
        # The official Sipeed Tang Nano 20K HDMI CST sets RESET pin 88
        # to LVCMOS33 with bank VCCIO=3.3. Do not silently regress.
        self.assertIn('IO_LOC "reset_btn" 88;', c)
        self.assertIn('IO_PORT "reset_btn" IO_TYPE=LVCMOS33 PULL_MODE=DOWN SINGLE_RESISTOR=ON BANK_VCCIO=3.3;', c)

    def test_single_bram_write_port_and_sync_read(self):
        s = (ROOT / 'rtl/pikosol20k_renderer.v').read_text()
        self.assertEqual(1, s.count('text_mem[ram_wr_addr] <= ram_wr_data;'))
        self.assertEqual(1, s.count('char_q <= text_mem[text_addr_s1];'))
        self.assertIn('always @(posedge pix_clk) begin\n        if (ram_wr_en)', s)
        self.assertIn('if (text_s1) char_q <= text_mem[text_addr_s1];', s)
        self.assertNotIn('text_mem[clear_offset] <=', s)
        self.assertNotIn('text_mem[cursor_row_base', s)

    def test_staged_rom_is_available_to_gowin(self):
        s = (ROOT / 'tools/stage.py').read_text()
        self.assertIn("for memory_file in ('lab04_boot.hex', 'lab04_font_8x12.hex'):", s)
        self.assertIn("out / 'rtl' / memory_file", s)

    def test_pipeline_and_independent_reset(self):
        top = (ROOT / 'rtl/pikosol20k_top.v').read_text()
        reset = (ROOT / 'rtl/pikosol20k_reset_ctrl.v').read_text()
        self.assertIn('.de(de_q), .px(px_q), .py(py_q)', top)
        self.assertIn('hs_d4', top)
        self.assertIn('.I_rst_n(resetn_serializer)', top)
        self.assertNotIn('pix_reset_request_n', top)
        # STA-4 matches the Sipeed vendor HDMI reset connection, not the
        # retired STA-3 serial_clk shift register.
        self.assertIn('assign resetn_serializer = raw_good;', reset)
        self.assertNotIn('posedge serial_clk', reset)
        self.assertIn('wire pixel_raw_good = raw_good;', reset)
        self.assertIn('wire sys_raw_good = raw_good;', reset)
        self.assertIn('assign resetn_serializer = raw_good;', reset)
        self.assertNotIn('reg [2:0] ser_release', reset)
        self.assertNotIn('raw_good && resetn_serializer', reset)
        self.assertNotIn('resetn_serializer && resetn_cpu', reset)
        self.assertIn('pikosol20k_reset_ctrl.v', (ROOT / 'gowin_build.tcl').read_text())

    def test_six_narrow_cdc_exceptions(self):
        s = (ROOT / 'constraints/pikosol20k.sdc').read_text()
        cmds = [line.strip() for line in s.splitlines() if line.strip().startswith('set_false_path')]
        self.assertEqual(len(cmds), 6)
        self.assertTrue(all('-through [get_pins {' in line for line in cmds))
        self.assertTrue(all(('ack_meta_sys' in line or 'req_meta_pixel' in line) for line in cmds))
        self.assertFalse(any('get_clocks' in line for line in cmds))

    def test_stage_cdc_attribute(self):
        s = (ROOT / 'tools/stage.py').read_text()
        self.assertIn('async_reg', s)
        self.assertIn('original.replace(a0, a1)', s)

    def test_new_simulation_testbenches(self):
        t = (ROOT / 'tests/tb_renderer.v').read_text()
        r = (ROOT / 'tests/tb_reset_ctrl.v').read_text()
        self.assertIn('sample_pixel(11\'d1279,10\'d500', t)
        self.assertIn("write_gfx(6'd63,24'd1)", t)
        self.assertIn('pll_locked=0;', r)
        self.assertIn('reset_btn=1;', r)

    def test_generated_firmware_hook(self):
        s = (ROOT / 'tools/stage.py').read_text()
        self.assertIn("('CAPACITY = 4096', 'CAPACITY = 8192')", s)
        self.assertIn("('lui s8, 0x4', 'lui s8, 0x10')", s)
        self.assertIn('for n in range(2, 8)', s)
        self.assertIn('8192', s)


if __name__ == '__main__':
    unittest.main()
