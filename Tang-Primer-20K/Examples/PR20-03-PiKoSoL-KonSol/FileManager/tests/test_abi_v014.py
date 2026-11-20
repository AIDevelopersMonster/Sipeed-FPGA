"""Regression tests for 2026-11-19 operator's audit (no COM, no FPGA)."""
from pathlib import Path
import hashlib
import struct
import tempfile
import unittest
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pikosol_core import inspect_binary, APP_ENTRY, APP_CAPACITY
from pikosol_xmodem import send_binary, TransferError
from build_tp20_apps import APPS, emulate, COLS, ROWS

class NoComWriter:
    def __init__(self): self.writes = []
    def write(self, data): self.writes.append(data); raise AssertionError('UART MUST NOT BE USED')
    def read(self, n): raise AssertionError('UART MUST NOT BE USED')

class TestOperatorPKD1Audit(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.dir.cleanup)
        self.root = Path(self.dir.name)
        self.demo = self.root/'demo.bin'
        self.demo.write_bytes(struct.pack('<IIII', 0x31444b50, 1292, APP_ENTRY, 0) + bytes(1276))
        self.published = Path(__file__).resolve().parents[1]/'generated'

    def test_all_five_new_app_headers_and_emu(self):
        for name in APPS:
            with self.subTest(name=name):
                p = self.published/name
                info = inspect_binary(p, self.demo)
                w = struct.unpack_from('<IIII', p.read_bytes())
                self.assertEqual(w, (0x31444b50, p.stat().st_size, APP_ENTRY, 0))
                self.assertLessEqual(info.padded_size, APP_CAPACITY)
                video, _ = emulate(p.read_bytes())
                self.assertEqual(len(video), COLS*ROWS)

    def test_operator_bug_wrong_length_detected_before_transfer(self):
        raw = (self.published/'TP20_HDMI_GRID.bin').read_bytes()
        altered = struct.pack('<IIII', 0x31444b50, 0, len(raw), 0) + raw[16:]
        p = self.root/'bad_length.bin'
        p.write_bytes(altered)
        with self.assertRaisesRegex(ValueError,'LOAD BAD LENGTH'):
            inspect_binary(p, self.demo)
        no_com = NoComWriter()
        with self.assertRaisesRegex(ValueError,'NO LOAD SENT'):
            send_binary(no_com, altered, lambda *a: None)
        self.assertEqual(no_com.writes, [])

    def test_bad_entry_and_reserved_refused(self):
        raw = (self.published/'TP20_HDMI_GRID.bin').read_bytes()
        for wrong in (0x1d14, 0, 0x2000c000):
            with self.subTest(entry=wrong):
                bad = bytearray(raw)
                struct.pack_into('<I', bad, 8, wrong)
                p = self.root/'bad.bin'
                p.write_bytes(bad)
                with self.assertRaisesRegex(ValueError, 'BAD ENTRY'):
                    inspect_binary(p, self.demo)
        bad=bytearray(raw); struct.pack_into('<I',bad,12,1)
        p=self.root/'bad.bin';p.write_bytes(bad)
        with self.assertRaisesRegex(ValueError,'BAD RESERVED'):
            inspect_binary(p,self.demo)

    def test_hello_builder_uses_same_abi(self):
        import build_hello_rv32i
        p = self.root/'hello.bin'
        raw = build_hello_rv32i.build(self.demo, p,
            _test_digest=hashlib.sha256(self.demo.read_bytes()).hexdigest())
        self.assertEqual(struct.unpack_from('<IIII',raw),
                         (0x31444b50,len(raw),APP_ENTRY,0))
        self.assertEqual(inspect_binary(p,self.demo).size,len(raw))
