#!/usr/bin/env python3
"""LAB-04.3.2 architecture/source checks; not a Gowin/board certificate."""
from pathlib import Path
import re, unittest
R=Path(__file__).resolve().parents[1]
def source(path): return (R/path).read_text(encoding='utf-8')
class ShellContract(unittest.TestCase):
    def test_ram_rom_nonoverlap_and_bram(self):
        soc=source('rtl/lab04_cpu_soc.v')
        rom=source('rtl/lab04_boot_rom.v')
        for v in ("mem_addr[31:14] == 18'b0", "mem_addr[31:10] == 22'd16",
                  'shell_ram [0:255]', 'if (ram_read)', 'if (ram_write)',
                  'mem_wstrb == 4\'hf', 'return_ram ? shell_ram_rdata'):
            self.assertIn(v,soc)
        self.assertIn('syn_ramstyle = "block_ram"',soc)
        self.assertIn('rom [0:4095]',rom)
        self.assertIn('syn_romstyle = "block_rom"',rom)
        self.assertIn('$readmemh("lab04_boot.hex", rom)',rom)
        self.assertIn('word_addr(mem_addr[13:2])',soc)

    def test_shell_line_editor_and_no_raw_host_echo(self):
        fw=source('firmware/lab04_boot.S')
        for value in ('backspace:', 'recall:', 'enter_cr:', 'enter_lf:',
                      'normalize_loop:', 'remember_loop:', 'line_enter:',
                      'command_table:', 's11', 'input_full:', 'PiKoSoL>'):
            self.assertIn(value,fw)
        self.assertIn('HOST_TAP_ENABLE(0)',source('rtl/lab04_cpu_hdmi_top.v'))
        self.assertIn('HOST_TAP_ENABLE = 1',source('rtl/lab04_uart_tty_bridge.v'))
        self.assertIn('HOST_TAP_ENABLE && host_byte_valid',source('rtl/lab04_uart_tty_bridge.v'))
        self.assertIn('lab04_uart_tty_bridge',source('rtl/lab04_cpu_hdmi_top.v'))

    def test_terminal_and_graphics_uis_use_same_cdc(self):
        osd=source('rtl/lab04_console_osd.v')
        for value in ('LOG_SIZE = 2432', 'LOG_COLS = 76', 'shell_term',
                      'term_log_here', 'gfx_log_here', '32 rows',
                      'char_event_byte', "8'h0e", "8'h0f", "12'd2431",
                      'b_term_backdrop', 'pixel_accept(!clearing)',
                      'font_row_b <= font_mem[font_addr]'):
            self.assertIn(value,osd)
        self.assertIn('lab04_tty_byte_cdc u_tty_cdc',osd)
        self.assertNotIn('set_false_path',source('constraints/lab04_cpu_video_v018b.sdc'))
        self.assertEqual(15,len(re.findall(r'^set_max_delay',source('constraints/lab04_cpu_video_v018b.sdc'),re.M)))
        self.assertIn('tty=8/8',source('tools/check_sta_v018b.py').replace('%d/8','8/8'))

    def test_live_keys_are_opt_in_and_use_existing_mmio(self):
        fw=source('firmware/lab04_boot.S')
        self.assertIn('.match "KEYS", cmd_keys',fw)
        self.assertIn('bne s10, zero, live_input',fw)
        self.assertIn('cmd_keys:',fw)
        self.assertIn('beq s4,zero,invalid_arg',fw)
        self.assertIn('LIVE KEYS:',fw)
        self.assertIn('bne s10, zero, poll',fw)
        self.assertIn('jal zero, video_done',fw)
        self.assertIn('addi s10,zero, 0',fw)
        board=source('tools/test_lab0432_board.ps1')
        self.assertIn("$sp.Write('jjjkkk')",board)
        self.assertIn("$sp.Write('T')",board)

    def test_build_stages_both_readmemh_sources(self):
        build=source('tools/build_lab04.ps1')
        self.assertIn("'lab04_boot.hex'",build)
        self.assertIn('firmware\\lab04_boot.hex',build)
        self.assertIn('lab04_font_8x12.hex',build)
        self.assertIn('Copy-Item -LiteralPath $rom',build)
        tcl=source('build_scripts/gowin_lab04_cpu.tcl')
        self.assertIn('lab04_cpu_video_v018b.sdc',tcl)
        self.assertIn('lab04_boot_rom.v',tcl)

if __name__=='__main__':unittest.main(verbosity=2)
