#!/usr/bin/env python3
"""Offline unit tests: fixtures are archived board dumps impersonating RTL.

A PASS here tests only the comparator and safe TB generator, NOT Icarus
simulation. The actual PS7 runner must later execute the true RTL testbench.
"""
from __future__ import annotations

import os
import io
import contextlib
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

TOOLS = Path(__file__).resolve().parent.parent / 'tools'
sys.path.insert(0, str(TOOLS))
import lab03_4_analyze as audit
import lab03_4_compare_dual as dual
import lab03_4_extend_tb as patch


TB_FIXTURE = '''`timescale 1ns/1ps
module tb_lab03_2_uart;
  integer start_trace,tx_count=0;
  task save_trace(input integer x,input integer y,input integer which);
    begin
      case(which)
      1:fd=$fopen("build/lab03_2_trace_4.txt","w");
      2:fd=$fopen("build/lab03_2_trace_4_repeat.txt","w");
      3:fd=$fopen("build/lab03_2_trace_1.txt","w");
      default:$fatal(1,"bad which");
      endcase
    end
  endtask
  initial begin
    host_send("4");
    host_send("T");
    host_send("T");
    host_send("C");
    host_send("1");
    host_send("T");
    save_trace(start_trace,tx_count,3);
    $display("LAB03_2_UART_TRACE_RTL_PASS: original");
    $finish;
  end
endmodule
'''


class ExtensionTests(unittest.TestCase):
    def test_additive_patch_keeps_existing_markers(self):
        source=TB_FIXTURE
        generated=patch.derive(source,'abc123')
        self.assertIn('LAB03_2_UART_TRACE_RTL_PASS: original', generated)
        self.assertIn('LAB03_4_ZERO_UART_TRACE_RTL_PASS', generated)
        self.assertIn('4:fd=$fopen("build/lab03_4_trace_0.txt","w");', generated)
        self.assertEqual(generated.count('host_send("T")'), 4)
        self.assertLess(generated.index('save_trace(start_trace,tx_count,3)'), generated.index('host_send("0")'))
        self.assertLess(generated.index('host_send("0")'), generated.index('LAB03_2_UART_TRACE_RTL_PASS: original'))
        self.assertEqual(source, TB_FIXTURE)

    def test_crlf_source_is_supported_without_modifying_original(self):
        source=TB_FIXTURE.replace('\n', '\r\n')
        generated=patch.derive(source)
        self.assertIn('LAB03_4_ZERO_UART_TRACE_RTL_PASS', generated)
        self.assertIn('4:fd=$fopen("build/lab03_4_trace_0.txt","w");',generated)
        self.assertNotIn('\r', generated)
        self.assertEqual(source, TB_FIXTURE.replace('\n', '\r\n'))

    def test_already_patched_fail_closed(self):
        generated=patch.derive(TB_FIXTURE)
        with self.assertRaises(patch.PatchError): patch.derive(generated)

    def test_missing_anchor_refuses(self):
        with self.assertRaises(patch.PatchError):
            patch.derive(TB_FIXTURE.replace('save_trace(start_trace,tx_count,3);', 'save_trace(0,1,3);'))

    def test_missing_original_T_refuses(self):
        with self.assertRaises(patch.PatchError):
            patch.derive(TB_FIXTURE.replace('host_send("T");', 'host_send("X");',1))

    def test_no_source_overwrite(self):
        with tempfile.TemporaryDirectory() as f:
            root=Path(f);source=root/'tb.v';source.write_bytes(TB_FIXTURE.replace('\n','\r\n').encode('utf-8'))
            destination=root/'build'/'generated.v'
            with contextlib.redirect_stdout(io.StringIO()):
                ret=patch.main(['--source',str(source),'--out',str(destination)])
            self.assertEqual(ret,0)
            self.assertEqual(source.read_bytes(),TB_FIXTURE.replace('\n','\r\n').encode('utf-8'))
            self.assertTrue(destination.exists())
            with contextlib.redirect_stderr(io.StringIO()):
                self.assertEqual(patch.main(['--source',str(source),'--out',str(source)]),1)


class ComparatorTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        path=Path(os.environ.get('LAB03_3_EVIDENCE',str(Path.home()/'Downloads'/'LAB03_3_EVIDENCE.zip')))
        if not path.is_file():
            raise unittest.SkipTest(f'Real evidence fixture not found: {path}')
        cls.archive=path
        cls.temporary=tempfile.TemporaryDirectory()
        cls.dir=Path(cls.temporary.name)
        with zipfile.ZipFile(path) as f:
            raw_rom=f.read('boot.hex')
            board=audit.analyze(audit.source_reader(path),rom_override=raw_rom)
            words=audit.rom_words(raw_rom)
            for pc, word in board['observed_words'].items(): words[pc // 4]=word
            cls.rom=cls.dir/'fixture_rom_not_real_build.hex'
            cls.rom.write_text(''.join(f'{x:08x}\n' for x in words),encoding='ascii')
            cls.buf0=f.read('raw/run_002_led_0.txt')
            cls.buf4=f.read('raw/run_001_led_4.txt')
        cls.rtl0=cls.dir/'rtl0.txt';cls.rtl4=cls.dir/'rtl4.txt';cls.log=cls.dir/'rtl.log'

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls,'temporary'): cls.temporary.cleanup()

    def setUp(self):
        self.rtl0.write_bytes(self.buf0)
        self.rtl4.write_bytes(self.buf4)
        self.log.write_text('LAB03_2_UART_TRACE_RTL_PASS: fixture only\nLAB03_4_ZERO_UART_TRACE_RTL_PASS: fixture only\n',encoding='ascii')

    def compare(self, **kwargs):
        opts=dict(evidence=self.archive,rom_path=self.rom,rtl_0=self.rtl0,rtl_4=self.rtl4,
                  rtl_log=self.log,expected_rom_sha256=None,expected_bitstream_sha256=None)
        opts.update(kwargs)
        return dual.compare_dual(**opts)

    def test_positive_both_commands(self):
        result=self.compare()
        self.assertTrue(result['pass'])
        self.assertEqual(result['commands']['0']['board_runs'],6)
        self.assertEqual(result['commands']['0']['board_core_fetches'],14)
        self.assertEqual(result['commands']['4']['board_core_fetches'],22)
        with tempfile.TemporaryDirectory() as root:
            dual.write_report(result,Path(root))
            self.assertIn('command 0',str(result['scope']).lower())
            self.assertEqual((Path(root)/'core_comparison.csv').read_text(encoding='utf-8-sig').count('MISMATCH'),0)

    def test_alternate_poll_prefix_both_commands(self):
        with zipfile.ZipFile(self.archive) as f:
            self.rtl0.write_bytes(f.read('raw/run_012_led_0.txt'))
            self.rtl4.write_bytes(f.read('raw/run_005_led_4.txt'))
        self.assertTrue(self.compare()['pass'])

    def test_order_error_with_valid_rom_words_is_mismatch(self):
        text=self.buf0.decode('ascii').splitlines()
        events=[i for i,x in enumerate(text) if x.startswith('E:')]
        core_ix=next(i for i in events if ':00000048:' in text[i])
        a=text[core_ix+1].split(':');b=text[core_ix+2].split(':')
        a[3],b[3]=b[3],a[3];a[4],b[4]=b[4],a[4]
        text[core_ix+1]=':'.join(a);text[core_ix+2]=':'.join(b)
        # Use a single CRLF transformation. Path.write_text on Windows would
        # apply universal-newline conversion and produce CR-CR-LF here.
        mutated=('\r\n'.join(text)+'\r\n').encode('ascii')
        audit.parse_dump(mutated,0,'mutated valid T3 fixture')
        self.rtl0.write_bytes(mutated)
        result=self.compare()
        self.assertFalse(result['pass'])
        self.assertTrue(result['commands']['0']['first_diff'])
        self.assertTrue(result['commands']['4']['pass'])

    def test_lf_mutation_is_also_parseable(self):
        # Byte-exact LF is valid too; the comparator cannot silently depend on
        # the host newline convention when reading a UART trace.
        self.rtl0.write_bytes(('\n'.join(self.buf0.decode('ascii').splitlines())+'\n').encode('ascii'))
        audit.parse_dump(self.rtl0.read_bytes(),0,'LF fixture')
        self.assertTrue(self.compare()['pass'])

    def test_wrong_led_value_is_blocked(self):
        self.rtl0.write_bytes(self.buf0.replace(b':20000000:00000000',b':20000000:00000008'))
        with self.assertRaises(audit.EvidenceError):self.compare()

    def test_missing_zero_marker_blocked(self):
        self.log.write_text('LAB03_2_UART_TRACE_RTL_PASS: only old tests\n')
        with self.assertRaises(audit.EvidenceError):self.compare()

    def test_wrong_rom_sha_blocked(self):
        with self.assertRaises(audit.EvidenceError):self.compare(expected_rom_sha256='0'*64)

    def test_wrong_campaign_bitstream_blocked(self):
        with self.assertRaises(audit.EvidenceError):self.compare(expected_bitstream_sha256='0'*64)

    def test_wrong_command_header_blocked(self):
        self.rtl0.write_bytes(self.buf0.replace(b':00000030',b':00000034',1))
        with self.assertRaises(audit.EvidenceError):self.compare()


if __name__ == '__main__':
    unittest.main(verbosity=2)
