"""Offline invariants for the one-file FAT32 write qualification gate."""
import json
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from scratch_gate import MAGIC, VERSION, new_image, sha, load_manifest

class ScratchGateTests(unittest.TestCase):
    def original(self):
        return (MAGIC + bytes(range(256)) * 2)[:512]

    def manifest(self, original):
        return {
            "format": VERSION, "file_name": "SDRWTEST.BIN",
            "scratch_lba": 20000, "file_cluster": 7, "file_size": 512,
            "partition_lba": 8192, "partition_sectors": 100000,
            "fat32_total": 100000, "data_lba": 18000,
            "sectors_per_cluster": 64,
            "mbr_sha256": sha(bytes(512)), "vbr_sha256": sha(bytes(512)),
            "preimage_sha256": sha(original),
            "newimage_sha256": sha(new_image(original)),
            "write_protocol": "UART-CAS-CMD17-CMD24-CMD17"
        }

    def check(self, doc, old):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t)
            (p / "manifest.json").write_text(json.dumps(doc), encoding="utf-8")
            (p / "backup.bin").write_bytes(old)
            return load_manifest(p / "manifest.json", p / "backup.bin")

    def test_reversible_single_sector(self):
        old = self.original()
        new = new_image(old)
        self.assertEqual(len(new), 512)
        self.assertEqual(new[:64], old[:64])
        self.assertNotEqual(new, old)
        self.assertEqual(new_image(new), old)
        doc, verified_old, verified_new = self.check(self.manifest(old), old)
        self.assertEqual(verified_old, old)
        self.assertEqual(verified_new, new)
        self.assertEqual(doc["scratch_lba"], 20000)

    def test_changed_backup_rejected(self):
        old = self.original()
        modified = bytearray(old)
        modified[-1] ^= 1
        with self.assertRaisesRegex(ValueError, "backup"):
            self.check(self.manifest(old), bytes(modified))

    def test_lba_zero_rejected(self):
        old = self.original()
        doc = self.manifest(old)
        doc["scratch_lba"] = 0
        with self.assertRaisesRegex(ValueError, "invalid scratch"):
            self.check(doc, old)

    def test_wrong_new_hash_rejected(self):
        old = self.original()
        doc = self.manifest(old)
        doc["newimage_sha256"] = "0" * 64
        with self.assertRaisesRegex(ValueError, "invalid scratch"):
            self.check(doc, old)

if __name__ == "__main__":
    unittest.main()
