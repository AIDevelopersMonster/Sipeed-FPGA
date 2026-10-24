import importlib.util
import pathlib
import struct
import sys
import unittest

file = pathlib.Path(__file__).resolve().parents[1] / "python/fat32_reader.py"
spec = importlib.util.spec_from_file_location("host02_fat", file)
fat = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = fat
spec.loader.exec_module(fat)


def u16(b, at, v):
    struct.pack_into("<H", b, at, v)

def u32(b, at, v):
    struct.pack_into("<I", b, at, v)

def mk_entry(name, first, size, attr=0x20):
    b = bytearray(32)
    b[:11] = name.encode("ascii")
    b[11] = attr
    u16(b, 26, first & 65535)
    u16(b, 20, first >> 16)
    u32(b, 28, size)
    return b


def make_lfn(name, short):
    units = list(name.encode("utf-16le"))
    pairs = [units[n:n+2] for n in range(0,len(units),2)]
    pairs.append([0,0])
    while len(pairs)%13:
        pairs.append([255,255])
    checksum = fat.lfn_checksum(short)
    out=[]
    for index in range(len(pairs)//13,0,-1):
        b=bytearray([255]*32)
        b[0]=index | (0x40 if index==len(pairs)//13 else 0)
        b[11]=0x0f
        b[12]=0
        b[13]=checksum
        b[26:28]=b"\x00\x00"
        subset=pairs[(index-1)*13:index*13]
        for pos, pair in zip((1,3,5,7,9,14,16,18,20,22,24,28,30),subset):
            b[pos:pos+2]=bytes(pair)
        out.append(bytes(b))
    return out


class FakeBlockDevice:
    """Sparse MBR FAT32 partition with non-contiguous 2-sector file."""
    def __init__(self):
        self.blocks={}
        self.calls=[]
        m=bytearray(512)
        m[446+4]=0x0c
        u32(m,446+8,64)
        u32(m,446+12,70000)
        m[-2:]=b"\x55\xaa"
        self.blocks[0]=bytes(m)
        v=bytearray(512)
        v[11:13]=b"\x00\x02"
        v[13]=1
        u16(v,14,32)
        v[16]=1
        u32(v,28,64)
        u32(v,32,70000)
        u32(v,36,600)
        u32(v,44,2)
        v[-2:]=b"\x55\xaa"
        self.blocks[64]=bytes(v)
        ft=bytearray(512)
        u32(ft,2*4,0x0fffffff) # ROOT cluster 2
        u32(ft,3*4,7)          # file fragment
        u32(ft,7*4,0x0fffffff) # file EOC
        u32(ft,4*4,4)          # corrupt loop for tests
        self.blocks[96]=bytes(ft)
        root=bytearray(512)
        short=b"LONGNA~1TXT"
        entries=make_lfn("Long Name.txt",short)
        pieces=entries+[bytes(mk_entry(short.decode("ascii"),3,520))]
        for i,item in enumerate(pieces):
            root[i*32:(i+1)*32]=item
        self.blocks[696]=bytes(root)     # first data LBA 64+32+600
        self.blocks[697]=b"A"*512
        self.blocks[701]=b"B"*8+bytes(504)
    def read(self,lba):
        self.calls.append(lba)
        return self.blocks.get(lba,bytes(512))


class ParserTests(unittest.TestCase):
    def setUp(self):
        self.device=FakeBlockDevice()
        self.fat=fat.FAT32(self.device.read)

    def test_geometry(self):
        self.assertEqual(self.fat.partition.first_lba,64)
        self.assertEqual(self.fat.first_fat_lba,96)
        self.assertEqual(self.fat.first_data_lba,696)
        self.assertEqual(self.fat.cluster_lba(3),697)
        self.assertGreaterEqual(self.fat.cluster_count,65525)

    def test_lfn_directory_and_alias(self):
        items=self.fat.list_path("/")
        self.assertEqual(len(items),1)
        self.assertEqual(items[0].name,"Long Name.txt")
        self.assertEqual(items[0].short_name,"LONGNA~1.TXT")
        self.assertEqual(self.fat.locate("/Long Name.txt"),items[0])
        self.assertEqual(self.fat.locate("/LONGNA~1.TXT"),items[0])

    def test_fragmented_file(self):
        self.assertEqual(self.fat.read_file("/Long Name.txt"),b"A"*512+b"B"*8)
        self.assertEqual(self.fat.read_file("/longna~1.txt"),b"A"*512+b"B"*8)
        self.assertEqual(self.device.calls.count(0),1)
        self.assertEqual(self.device.calls.count(64),1)

    def test_file_limit(self):
        with self.assertRaisesRegex(fat.FATError,"max_bytes"):
            self.fat.read_file("/Long Name.txt",max_bytes=128)

    def test_bad_signature(self):
        invalid=FakeBlockDevice()
        m=bytearray(invalid.blocks[0])
        m[-2:]=b"\x00\x00"
        invalid.blocks[0]=bytes(m)
        with self.assertRaisesRegex(fat.FATError,"signature"):
            fat.FAT32(invalid.read)

    def test_no_fat32_partition(self):
        invalid=FakeBlockDevice()
        m=bytearray(invalid.blocks[0]);m[450]=0x07
        invalid.blocks[0]=bytes(m)
        with self.assertRaisesRegex(fat.FATError,"no MBR FAT32 partition"):
            fat.FAT32(invalid.read)

    def test_cycle_detection(self):
        with self.assertRaisesRegex(fat.FATError,"cycle"):
            list(self.fat.cluster_chain(4))

    def test_fat_budget(self):
        with self.assertRaisesRegex(fat.FATError,"safety limit"):
            fat.FAT32(self.device.read,max_sector_reads=1)

    def test_short_sector_rejected(self):
        invalid=FakeBlockDevice()
        invalid.blocks[0]=b""
        with self.assertRaisesRegex(fat.FATError,"sector size"):
            fat.FAT32(invalid.read)

    def test_parent_traversal_rejected(self):
        with self.assertRaisesRegex(fat.FATError,"parent-directory"):
            self.fat.locate("../Long Name.txt")


if __name__=="__main__":
    unittest.main()
