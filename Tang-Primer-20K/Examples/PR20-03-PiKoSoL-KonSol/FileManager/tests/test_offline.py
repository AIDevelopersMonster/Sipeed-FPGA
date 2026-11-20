"""Offline regression tests. No COM, no FPGA, no Flash."""
import hashlib
from pathlib import Path
import sys
import struct
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pikosol_core import (Paths, inspect_binary, command_for_host,
    parse_transfer_output, APP_CAPACITY, XMODEM_BLOCK_SIZE)
from build_hello_rv32i import build, emulate, BANNER


class TestFileManager(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.d = Path(self.tmp.name)
        self.demo = self.d/'demo.bin'
        self.demo.write_bytes(struct.pack('<IIII', 0x31444b50, 1292, 0x2000c010, 0) + bytes(1276))

    def test_builder_and_guard(self):
        program = self.d/'HELLO_PiKoSoL_TP20.bin'
        raw = build(self.demo, program, _test_digest=hashlib.sha256(self.demo.read_bytes()).hexdigest())
        info = inspect_binary(program, self.demo)
        self.assertEqual(info.size, len(raw))
        self.assertEqual(info.padded_size % XMODEM_BLOCK_SIZE, 0)
        self.assertEqual(info.blocks, 3)
        self.assertEqual(info.header[0], 0x31444b50)
        self.assertEqual(info.header[1], len(raw))
        self.assertEqual(info.header[2], 0x2000c010)
        ok, words = emulate(raw[16:], 0x2000C010)
        self.assertTrue(ok)
        self.assertEqual(''.join(chr(value & 255) for value in words.values()), BANNER)

    def test_guard_rejects_fpga_elf_oversize(self):
        f = self.d/'bad.fs'
        f.write_bytes(self.demo.read_bytes())
        with self.assertRaisesRegex(ValueError, 'raw RV32I'):
            inspect_binary(f, self.demo)
        f = self.d/'bad.bin'
        f.write_bytes(b'Z'*32)
        with self.assertRaisesRegex(ValueError, 'сигнатура'):
            inspect_binary(f, self.demo)
        f.write_bytes(self.demo.read_bytes()[:16] + bytes(APP_CAPACITY))
        with self.assertRaisesRegex(ValueError, 'Превышено'):
            inspect_binary(f, self.demo)

    def test_cmd_and_host_status(self):
        p = Paths.from_root(self.d)
        cmd = command_for_host(p, self.demo, port='COM10')
        self.assertIn('--attach', cmd)
        self.assertIn('--auto-demo', cmd)
        self.assertEqual(cmd[cmd.index('--demo')+1], str(self.demo))
        restore = command_for_host(p, self.demo, operation='monitor')
        self.assertNotIn('--attach', restore)
        self.assertNotIn('--auto-demo', restore)
        sample = '''XMODEM transfer ACK / PASS\nRUN 2000C010\nRULE30 CPU CHECKSUM=0xD2A3C779\nRUN RETURNED TO PiKoSoL\n'''
        res = parse_transfer_output(sample, 0)
        self.assertTrue(res.pass_app)
        self.assertTrue(parse_transfer_output('RUN 2000C010\nRUN RETURNED TO PiKoSoL\nSERIAL TEST PASS', 0).pass_app)
        self.assertFalse(parse_transfer_output('ERROR: timeout', 3).pass_app)
        self.assertFalse(parse_transfer_output('RUN 2000C010', 0).pass_app)

    def test_auto_root_chooses_hashed_valid_copy(self):
        """Regression: an older external unpack must not shadow a valid nested kit."""
        import pikosol_core as core
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            downloads = home / 'Downloads'
            base = downloads / 'TP20_PiKoSoL_PicoRV32_UART_HDMI_TEST'
            nested = base / base.name
            for folder, monitor in ((base,b'BAD!'),(nested,b'GOOD')):
                (folder/'tools').mkdir(parents=True)
                (folder/'firmware').mkdir()
                (folder/'tools'/'host_console.py').write_text('# tool')
                (folder/'firmware'/'monitor.bin').write_bytes(monitor)
                (folder/'firmware'/'demo.bin').write_bytes(b'BAR')
            with (mock.patch.object(core.Path, 'home', return_value=home),
                  mock.patch.object(core, 'MONITOR_SIZE', 4),
                  mock.patch.object(core, 'DEMO_SIZE', 3),
                  mock.patch.object(core, 'MONITOR_SHA256', hashlib.sha256(b'GOOD').hexdigest()),
                  mock.patch.object(core, 'DEMO_SHA256', hashlib.sha256(b'BAR').hexdigest())):
                found = core.auto_paths(downloads/'PiKoSoL_TP20_FileManager_CANDIDATE_v0.1.1')
                self.assertEqual(found.root, nested)
                self.assertIn('MONITOR SHA256 PASS', core.check_baseline(found))
                with self.assertRaisesRegex(ValueError,'SHA256 ФАКТ'):
                    core.check_baseline(core.Paths.from_root(base))


    def test_sha256_references_are_full_length(self):
        import pikosol_core as core
        self.assertEqual(core.MONITOR_SHA256, '414d8b9859ce95826e9a0ba12a26e820af2942cd4fd964ea9ff75ac28ae135c7')
        self.assertEqual(len(core.MONITOR_SHA256), 64)
        self.assertEqual(len(core.DEMO_SHA256), 64)
        core.assert_hash_reference_integrity()
        with mock.patch.object(core, 'MONITOR_SHA256', core.MONITOR_SHA256[:53]):
            with self.assertRaisesRegex(RuntimeError, 'длину 53 вместо 64'):
                core.assert_hash_reference_integrity()

    def test_baseline_passes_exact_64_digit_hash_and_rejects_mismatch(self):
        import pikosol_core as core
        base = self.d / 'kit'
        (base/'tools').mkdir(parents=True)
        (base/'firmware').mkdir()
        (base/'tools'/'host_console.py').write_text('# mock only', encoding='utf-8')
        monitor_bytes = b'Z'*18560
        demo_bytes = b'Q'*1292
        (base/'firmware'/'monitor.bin').write_bytes(monitor_bytes)
        (base/'firmware'/'demo.bin').write_bytes(demo_bytes)
        sha_monitor = hashlib.sha256(monitor_bytes).hexdigest()
        sha_demo = hashlib.sha256(demo_bytes).hexdigest()
        self.assertEqual(len(sha_monitor),64)
        with (mock.patch.object(core, 'MONITOR_SHA256', sha_monitor),
              mock.patch.object(core, 'DEMO_SHA256', sha_demo)):
            paths=core.Paths.from_root(base)
            self.assertTrue(core.baseline_is_verified(paths))
            self.assertIn('MONITOR SHA256 PASS',core.check_baseline(paths))
            with mock.patch.object(core, 'MONITOR_SHA256', sha_monitor[:53]):
                with self.assertRaisesRegex(RuntimeError,'вместо 64'):
                    core.check_baseline(paths)
            with mock.patch.object(core, 'MONITOR_SHA256','0'*64):
                with self.assertRaisesRegex(ValueError,'SHA256 ФАКТ'):
                    core.check_baseline(paths)

    def test_xmodem_padding_edges(self):
        for length in (128, 129, APP_CAPACITY):
            f = self.d/'test.bin'
            f.write_bytes(struct.pack('<IIII', 0x31444b50, length, 0x2000c010, 0) + bytes(length - 16))
            i = inspect_binary(f, self.demo)
            self.assertLessEqual(i.padded_size, APP_CAPACITY)


if __name__ == '__main__':
    unittest.main(verbosity=2)
