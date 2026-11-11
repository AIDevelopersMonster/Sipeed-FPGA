"""Synthetic FAT32 regression: no COM, no physical card, no writes."""
import sys
import unittest
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from fat32_host import FAT32Volume, FAT32Error, short_checksum, lfn_name

def pack16(b, pos, val):
    b[pos:pos+2] = val.to_bytes(2,"little")

def pack32(b, pos, val):
    b[pos:pos+4] = val.to_bytes(4,"little")

def make_entry(name11, attr, cluster, size=0):
    b=bytearray(32)
    b[:11]=name11
    b[11]=attr
    pack16(b,20,cluster>>16)
    pack16(b,26,cluster&65535)
    pack32(b,28,size)
    return bytes(b)

def make_lfn(name, alias):
    # one record for max 13 UTF-16 code units
    raw=name.encode("utf-16le")
    units=[raw[i:i+2] for i in range(0,len(raw),2)]
    assert len(units)<=13
    units += [b"\x00\x00"]
    units = (units + [b"\xFF\xFF"]*13)[:13]
    b=bytearray(32)
    b[0]=0x41
    b[11]=0x0F
    b[13]=short_checksum(alias)
    for start,stop,words in ((1,11,units[:5]),(14,26,units[5:11]),(28,32,units[11:])):
        b[start:stop]=b"".join(words)
    return bytes(b)

def fixture(loop=False):
    disk={}
    mbr=bytearray(512)
    mbr[446+4]=0x0B
    pack32(mbr,446+8,64)
    pack32(mbr,446+12,70000)
    mbr[510:512]=bytes.fromhex("55AA")
    disk[0]=bytes(mbr)
    vbr=bytearray(512)
    pack16(vbr,11,512)
    vbr[13]=1
    pack16(vbr,14,1)
    vbr[16]=1
    pack32(vbr,32,70000)
    pack32(vbr,36,600)
    pack32(vbr,44,2)
    vbr[510:512]=bytes.fromhex("55AA")
    disk[64]=bytes(vbr)
    # FAT starts 65, data starts 665, cluster 2 root, 3/4 file.
    fat=bytearray(512)
    for cluster,value in ((0,0x0FFFFFF8),(1,0xFFFFFFFF),
                          (2,0x0FFFFFFF),(3,3 if loop else 4),
                          (4,0x0FFFFFFF)):
        pack32(fat,4*cluster,value)
    disk[65]=bytes(fat)
    alias=b"HELLO   TXT"
    root=bytearray(512)
    root[:32]=make_lfn("Hello World",alias)
    root[32:64]=make_entry(alias,0x20,3,600)
    root[64]=0
    disk[665]=bytes(root)
    disk[666]=b"A"*512
    disk[667]=b"B"*512
    return disk

class FAT32Tests(unittest.TestCase):
    def test_lfn(self):
        alias=b"HELLO   TXT"
        lfn=make_lfn("Hello World",alias)
        self.assertEqual(lfn_name([lfn],alias),"Hello World")
        self.assertIsNone(lfn_name([lfn],b"WRONG   TXT"))
    def test_listing_and_multicluster_copy(self):
        disk=fixture()
        vol=FAT32Volume(lambda lba:disk.get(lba,bytes(512)), max_sectors=10)
        self.assertEqual(vol.root_lba,665)
        listed=vol.listdir()
        self.assertEqual(len(listed),1)
        self.assertEqual(listed[0].name,"Hello World")
        self.assertEqual(vol.file_bytes("Hello World"),b"A"*512+b"B"*88)
        self.assertEqual(vol.file_bytes("HELLO.TXT"),b"A"*512+b"B"*88)
    def test_size_limit(self):
        disk=fixture()
        vol=FAT32Volume(lambda lba:disk.get(lba,bytes(512)))
        with self.assertRaisesRegex(FAT32Error,"safety limit"):
            vol.file_bytes("HELLO.TXT",max_file_bytes=200)
    def test_loop_fails_closed(self):
        disk=fixture(loop=True)
        vol=FAT32Volume(lambda lba:disk.get(lba,bytes(512)))
        with self.assertRaises(FAT32Error):
            vol.file_bytes("HELLO.TXT")
    def test_invalid_signature(self):
        disk=fixture()
        disk[0]=bytes(512)
        with self.assertRaisesRegex(FAT32Error,"MBR signature"):
            FAT32Volume(lambda lba:disk.get(lba,bytes(512)))

if __name__=="__main__":
    unittest.main()
