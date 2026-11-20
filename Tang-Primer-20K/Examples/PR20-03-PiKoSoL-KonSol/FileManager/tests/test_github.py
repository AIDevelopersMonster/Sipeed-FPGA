"""Offline-only tests: no network, serial, or FPGA."""
import hashlib
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from pikosol_github import PROJECT, parse_manifest, download_verified


class TestGithubCatalog(unittest.TestCase):
    def setUp(self):
        self.data = b'PKD1' + (20).to_bytes(4, 'little') + (0x2000C010).to_bytes(4, 'little') + bytes(8)
        self.entry = dict(name='demo.bin', path=PROJECT + '/firmware/demo.bin',
                          sha256=hashlib.sha256(self.data).hexdigest(),
                          bytes=len(self.data), board_pass=True, status='BOARD_PASS')

    def test_allowlist(self):
        import json
        self.assertEqual(parse_manifest(json.dumps(dict(schema=1, apps=[self.entry])).encode())[0]['name'], 'demo.bin')

    def test_reject_unsafe(self):
        import json
        for change in [dict(name='../evil.bin'), dict(sha256='invalid-digest'),
                       dict(board_pass=False), dict(bytes=99999)]:
            bad = dict(self.entry, **change)
            with self.assertRaises(ValueError):
                parse_manifest(json.dumps(dict(schema=1, apps=[bad])).encode())

    def test_download_verified_and_no_overwrite(self):
        with tempfile.TemporaryDirectory() as folder:
            directory = Path(folder)
            demo = directory / 'reference.bin'
            demo.write_bytes(self.data)
            def fetch(url, limit):
                self.assertIn('raw.githubusercontent.com', url)
                return self.data
            seen = []
            def inspect(path, demo_path):
                seen.append((path.read_bytes(), demo_path))
            saved = download_verified(self.entry, directory / 'cache', demo,
                                      fetch=fetch, inspect=inspect)
            self.assertEqual(saved.read_bytes(), self.data)
            self.assertEqual(len(seen), 1)
            self.assertEqual(download_verified(self.entry, directory / 'cache', demo,
                                               fetch=fetch, inspect=inspect), saved)
            saved.write_bytes(b'operator data')
            with self.assertRaises(FileExistsError):
                download_verified(self.entry, directory / 'cache', demo, fetch=fetch)

    def test_digest_mismatch_never_publishes(self):
        with tempfile.TemporaryDirectory() as folder:
            cache = Path(folder) / 'cache'
            with self.assertRaises(ValueError):
                download_verified(self.entry, cache, Path(folder) / 'demo.bin',
                                  fetch=lambda url, limit: b'not the listed bytes')
            self.assertFalse((cache / 'demo.bin').exists())


if __name__ == '__main__':
    unittest.main()
