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

    def test_current_legacy_catalog_and_new_catalog(self):
        """Both published manifests are valid for their respective clients."""
        import json
        from pikosol_github import MANIFEST
        project = Path(__file__).resolve().parents[1]
        legacy = project / 'FileManager' / 'verified-apps.json'
        current = project / 'FileManager' / 'verified-apps-v2.json'
        self.assertTrue(MANIFEST.endswith('/verified-apps-v2.json'))
        old = parse_manifest(legacy.read_bytes())
        new = parse_manifest(current.read_bytes())
        self.assertEqual(len(old), 12)
        self.assertEqual(len([x for x in old if x['requires'] == 'GPIO_V3714']), 6)
        for app in old[6:]:
            self.assertTrue(app['name'].endswith('__GPIO_V3714_ONLY.bin'))
            self.assertTrue(app['path'].endswith('/FileManager/generated/' + app['name']))
        self.assertEqual(len(new), 12)
        self.assertEqual(len([x for x in new if x['requires'] == 'GPIO_V3714']), 6)
        self.assertEqual([x['name'] for x in new[:6]], [x['name'] for x in old[:6]])
        self.assertEqual([x['sha256'] for x in new[6:]], [x['sha256'] for x in old[6:]])

    def test_new_catalog_row_does_not_break_existing_entries(self):
        import json
        from pikosol_github import PROJECT
        future = dict(name='PR20_SD04_FAT32_FILE_READ.bin',
                      path=PROJECT + '/SD-FAT32/bin/PR20_SD04_FAT32_FILE_READ.bin',
                      sha256='0' * 64, bytes=512, board_pass=False,
                      status='UNKNOWN', requires='SD_READ_ONLY')
        manifest = {'schema': 1, 'apps': [self.entry, future, dict(name='../invalid.bin')]}
        with self.assertRaises(ValueError):
            parse_manifest(json.dumps(manifest).encode())
        entries = parse_manifest(json.dumps(manifest).encode(), tolerant=True)
        self.assertEqual(len(entries), 2)
        self.assertEqual(entries[1]['requires'], 'SD_READ_ONLY')

    def test_reject_unknown_module_without_requirements(self):
        import json
        item = dict(name='app.bin', path=PROJECT + '/Future-SD/bin/app.bin',
                    sha256='0' * 64, bytes=512, board_pass=False,
                    status='UNKNOWN')
        with self.assertRaises(ValueError):
            parse_manifest(json.dumps({'schema': 1, 'apps': [item]}).encode())

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
