"""SD-05.2 regression: physically sized 32-KiB clusters and fragmented FAT.

A sparse in-memory map mimics the confirmed SD-03/SD-05 card geometry.
No physical SD access, writes, serial hardware, or large image file.
"""
import hashlib
import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from fat32_host import FAT32Volume, FAT32Error

CLUSTER_SIZE = 64 * 512
SIZE = CLUSTER_SIZE + 1025
ROOT_LBA = 17472
NEXT_CLUSTER_LBA = ROOT_LBA + (7 - 2) * 64
FIRST_CLUSTER_LBA = ROOT_LBA + 64
FAT_LBA = 2112


def set16(buf, off, value):
    buf[off:off + 2] = value.to_bytes(2, "little")


def set32(buf, off, value):
    buf[off:off + 4] = value.to_bytes(4, "little")


def sector_pattern(cluster, sector):
    seed = f"SD052:cluster={cluster}:sector={sector}".encode("ascii")
    return hashlib.sha256(seed).digest() * 16


def make_disk(*, invalid_chain=None, directory_on_second_sector=False):
    sectors = {}
    mbr = bytearray(512)
    mbr[446 + 4] = 0x0B
    set32(mbr, 446 + 8, 64)
    set32(mbr, 446 + 12, 62929856)
    mbr[510:512] = bytes.fromhex("55AA")
    sectors[0] = bytes(mbr)

    bpb = bytearray(512)
    set16(bpb, 11, 512)
    bpb[13] = 64
    set16(bpb, 14, 2048)
    bpb[16] = 2
    set32(bpb, 32, 62929856)
    set32(bpb, 36, 7680)
    set32(bpb, 44, 2)
    bpb[510:512] = bytes.fromhex("55AA")
    sectors[64] = bytes(bpb)

    fat = bytearray(512)
    for cluster, successor in (
        (0, 0x0FFFFFF8), (1, 0x0FFFFFFF),
        (2, 0x0FFFFFFF), (3, 7 if invalid_chain is None else invalid_chain),
        (7, 0x0FFFFFFF)
    ):
        set32(fat, cluster * 4, successor)
    sectors[FAT_LBA] = bytes(fat)

    record = bytearray(32)
    record[:11] = b"CHAIN   BIN"
    record[11] = 0x20
    set16(record, 26, 3)
    set32(record, 28, SIZE)
    directory = bytearray(512)
    directory[:32] = record
    if directory_on_second_sector:
        sectors[ROOT_LBA] = bytes([0xE5] * 512)  # 16 deleted records
        sectors[ROOT_LBA + 1] = bytes(directory)
    else:
        sectors[ROOT_LBA] = bytes(directory)

    expected = bytearray()
    for i in range(64):
        chunk = sector_pattern(3, i)
        sectors[FIRST_CLUSTER_LBA + i] = chunk
        expected.extend(chunk)
    for i in range(3):
        chunk = sector_pattern(7, i)
        sectors[NEXT_CLUSTER_LBA + i] = chunk
        expected.extend(chunk[:min(512, SIZE - len(expected))])
    assert len(expected) == SIZE
    return sectors, bytes(expected)


class MultiClusterTests(unittest.TestCase):
    def setUp(self):
        self.disk, self.expected = make_disk()
        self.reads = []

    def fetch(self, lba):
        self.reads.append(lba)
        if lba not in self.disk:
            raise AssertionError(f"fixture is missing LBA {lba}")
        return self.disk[lba]

    def test_physical_geometry_and_fragmented_chain(self):
        fs = FAT32Volume(self.fetch, max_sectors=90)
        self.assertEqual((fs.spc, fs.fat_lba, fs.root_lba), (64, 2112, 17472))
        self.assertEqual(fs.listdir()[0].name, "CHAIN.BIN")
        data = fs.file_bytes("/CHAIN.BIN")
        self.assertEqual(len(data), SIZE)
        self.assertEqual(hashlib.sha256(data).digest(),
                         hashlib.sha256(self.expected).digest())
        self.assertEqual(data, self.expected)
        self.assertIn(FAT_LBA, self.reads)
        self.assertIn(FIRST_CLUSTER_LBA, self.reads)
        self.assertIn(NEXT_CLUSTER_LBA, self.reads)
        self.assertNotIn(ROOT_LBA + (4 - 2) * 64, self.reads)
        print("SD052_FRAGMENTED_CLUSTER_PASS: 32-KiB + 1025 bytes, FAT[3]->7")

    def test_directory_across_sector_boundary(self):
        disk, _ = make_disk(directory_on_second_sector=True)
        fs = FAT32Volume(lambda lba: disk[lba], max_sectors=10)
        self.assertEqual(fs.listdir()[0].alias, "CHAIN.BIN")
        self.assertEqual(fs.file_bytes("CHAIN.BIN"), self.expected)

    def test_broken_chain_fails_closed(self):
        for bad in (3, 0x0FFFFFFF, 0, 1, 0x0FFFFFF7):
            with self.subTest(bad=bad):
                disk, _ = make_disk(invalid_chain=bad)
                fs = FAT32Volume(lambda lba: disk[lba], max_sectors=90)
                with self.assertRaises(FAT32Error):
                    fs.file_bytes("CHAIN.BIN")

    def test_safety_read_budget_and_file_size(self):
        fs = FAT32Volume(self.fetch, max_sectors=10)
        with self.assertRaisesRegex(FAT32Error, "safety limit"):
            fs.file_bytes("CHAIN.BIN", max_file_bytes=32768)
        with self.assertRaisesRegex(FAT32Error, "read-budget"):
            fs.file_bytes("CHAIN.BIN", max_file_bytes=65536)


if __name__ == "__main__":
    unittest.main()
