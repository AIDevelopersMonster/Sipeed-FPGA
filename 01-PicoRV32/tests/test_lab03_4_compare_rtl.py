#!/usr/bin/env python3
"""Tests compare logic against existing board evidence used only as fixture.

A board trace used as a stand-in for RTL in these offline unit tests is NOT
an independent RTL experiment. The real runner compiles and runs Icarus.
"""
from __future__ import annotations

import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve()
TOOLS = HERE.parent.parent / 'tools'
sys.path.insert(0, str(TOOLS))
import lab03_4_analyze as audit
import lab03_4_compare_rtl as compare


class CompareTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Override via env is supported for locally installed artifact.
        import os
        evidence = os.environ.get('LAB03_3_EVIDENCE', str(Path.home() / 'Downloads' / 'LAB03_3_EVIDENCE.zip'))
        cls.archive = Path(evidence)
        if not cls.archive.is_file():
            raise unittest.SkipTest(f'Evidence fixture absent: {cls.archive}')
        cls.tmp = tempfile.TemporaryDirectory()
        cls.tmpdir = Path(cls.tmp.name)
        with zipfile.ZipFile(cls.archive) as zf:
            old_rom = zf.read('boot.hex')
            observed = audit.analyze(audit.source_reader(cls.archive), rom_override=old_rom)
            words = audit.rom_words(old_rom)
            for pc, word in observed['observed_words'].items():
                words[pc // 4] = word
            cls.rom = cls.tmpdir / 'verified_observed_rom.hex'
            cls.rom.write_text('\n'.join(f'{w:08x}' for w in words) + '\n', encoding='ascii')
            cls.rtl = cls.tmpdir / 'rtl_dump.txt'
            cls.rtl.write_bytes(zf.read('raw/run_001_led_4.txt'))
        cls.log = cls.tmpdir / 'rtl.log'
        cls.log.write_text('LAB03_2_UART_TRACE_RTL_PASS: synthetic test fixture\n', encoding='utf-8')

    @classmethod
    def tearDownClass(cls):
        if hasattr(cls, 'tmp'):
            cls.tmp.cleanup()

    def setUp(self):
        # Restore isolated files: no test may inherit another test's mutation.
        with zipfile.ZipFile(self.archive) as zf:
            self.rtl.write_bytes(zf.read('raw/run_001_led_4.txt'))
        self.log.write_text('LAB03_2_UART_TRACE_RTL_PASS: synthetic test fixture\n', encoding='utf-8')

    def try_compare(self, **kwargs):
        defaults = dict(evidence=self.archive, rom_file=self.rom, rtl_file=self.rtl,
                        rtl_log=self.log, command=4)
        defaults.update(kwargs)
        return compare.compare(**defaults)

    def test_positive_same_normalized_core(self):
        result = self.try_compare()
        self.assertTrue(result['pass'])
        self.assertEqual(result['board_core_fetches'], 22)
        self.assertEqual(result['rtl_core_fetches'], 22)
        self.assertEqual(result['board_runs'], 6)

    def test_varying_valid_poll_prefix_still_matches(self):
        with zipfile.ZipFile(self.archive) as zf:
            self.rtl.write_bytes(zf.read('raw/run_005_led_4.txt'))
        self.assertTrue(self.try_compare()['pass'])

    def test_wrong_middle_bus_event_detected(self):
        with zipfile.ZipFile(self.archive) as zf:
            source = zf.read('raw/run_001_led_4.txt').decode('ascii')
        lines = source.splitlines()
        # Flip two complete addresses+words in the *core*, leaving their timestamps
        # and event indices unchanged, and preserving per-address ROM validity.
        a = lines[8].split(':')
        b = lines[9].split(':')
        a[3], b[3] = b[3], a[3]
        a[4], b[4] = b[4], a[4]
        lines[8] = ':'.join(a)
        lines[9] = ':'.join(b)
        self.rtl.write_text('\n'.join(lines) + '\n', encoding='ascii')
        result = self.try_compare()
        self.assertFalse(result['pass'])
        self.assertTrue(result['diffs'])
        with tempfile.TemporaryDirectory() as folder:
            compare.write_report(result, Path(folder))
            self.assertTrue((Path(folder) / 'core_comparison.csv').is_file())
            self.assertIn('MISMATCH', (Path(folder) / 'report.md').read_text(encoding='utf-8'))

    def test_missing_simulation_pass_marker_blocks(self):
        self.log.write_text('simulation failed\n', encoding='ascii')
        with self.assertRaises(audit.EvidenceError):
            self.try_compare()

    def test_wrong_rom_hash_blocks(self):
        with self.assertRaises(audit.EvidenceError):
            self.try_compare(expected_rom_sha256='0' * 64)

    def test_wrong_bitstream_declaration_blocks(self):
        with self.assertRaises(audit.EvidenceError):
            self.try_compare(expected_bitstream_sha256='0' * 64)

    def test_command_one_not_mistaken_for_four(self):
        with self.assertRaises(audit.EvidenceError):
            self.try_compare(command=1)

    def test_corrupt_rtl_header_command_blocks(self):
        with zipfile.ZipFile(self.archive) as zf:
            source = zf.read('raw/run_001_led_4.txt')
        self.rtl.write_bytes(source.replace(b'T3:0380011a:00000034', b'T3:0380011a:00000030', 1))
        with self.assertRaises(audit.EvidenceError):
            self.try_compare()


if __name__ == '__main__':
    unittest.main(verbosity=2)
