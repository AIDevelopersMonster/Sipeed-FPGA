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

    def test_single_bram_write_port_and_sync_read(self):
        s = (ROOT / 'rtl/pikosol20k_renderer.v').read_text()
        self.assertEqual(1, s.count('text_mem[ram_wr_addr] <= ram_wr_data;'))
        self.assertEqual(1, s.count('char_q <= text_mem[text_addr];'))
        self.assertIn('always @(posedge pix_clk) begin\n        if (ram_wr_en)', s)
        self.assertIn('if (de && !clearing) char_q <= text_mem[text_addr];', s)
        self.assertNotIn('text_mem[clear_offset] <=', s)
        self.assertNotIn('text_mem[cursor_row_base', s)

    def test_staged_rom_is_available_to_gowin(self):
        s = (ROOT / 'tools/stage.py').read_text()
        self.assertIn("for memory_file in ('lab04_boot.hex', 'lab04_font_8x12.hex'):", s)
        self.assertIn("out / 'rtl' / memory_file", s)

    def test_generated_firmware_hook(self):
        s = (ROOT / 'tools/stage.py').read_text()
        self.assertIn("('CAPACITY = 4096', 'CAPACITY = 8192')", s)
        self.assertIn("('lui s8, 0x4', 'lui s8, 0x10')", s)
        self.assertIn('for n in range(2, 8)', s)
        self.assertIn('8192', s)


if __name__ == '__main__':
    unittest.main()
