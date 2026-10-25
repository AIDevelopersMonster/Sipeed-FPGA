#!/usr/bin/env python3
"""Offline FAT32 geometry audit of SD-05 captures. No card I/O, no writes."""
import argparse
import hashlib
from pathlib import Path

KNOWN = {
    "mbr": "6CAC3744FFD5A7FA579AED8667A763E11C186FDF666F8536FEC69EFFAEA9F586",
    "vbr": "2205E5F07ED9FBCEA8FAED3363CF35B22D198139072285C6834C282A854D05FC",
    "root": "A545DFF293AE619D471BB8E97311DF4004D2FF01AF0DFA2EA2205469E45BEF7F",
}

def u16(buf, offset):
    return int.from_bytes(buf[offset:offset+2], "little")

def u32(buf, offset):
    return int.from_bytes(buf[offset:offset+4], "little")

def check(mbr, vbr, root, *, require_hashes=True, require_sd03=True):
    for name, data in (("mbr", mbr), ("vbr", vbr), ("root", root)):
        if len(data) != 512:
            raise ValueError(f"{name}: expected 512 bytes, received {len(data)}")
        sha = hashlib.sha256(data).hexdigest().upper()
        print(f"SD05_{name.upper()}_SHA256={sha}")
        if require_hashes and sha != KNOWN[name]:
            raise ValueError(f"{name}: SHA256 differs from recorded readback")
    if mbr[510:512] != bytes.fromhex("55AA"):
        raise ValueError("MBR boot signature differs from 55AA")
    partitions = []
    for i in range(4):
        off = 446 + 16*i
        ptype = mbr[off+4]
        start = u32(mbr, off+8)
        size = u32(mbr, off+12)
        if ptype or start or size:
            partitions.append((i, ptype, start, size))
            print(f"PARTITION[{i}]: TYPE={ptype:02X} START={start} SIZE={size}")
    candidates = [p for p in partitions if p[1] in (0x0B, 0x0C) and p[2] == 64]
    if not candidates:
        raise ValueError("FAT32 partition beginning at LBA 64 not found in MBR")
    if vbr[510:512] != bytes.fromhex("55AA"):
        raise ValueError("VBR boot signature differs from 55AA")
    bps = u16(vbr, 11)
    spc = vbr[13]
    reserved = u16(vbr, 14)
    fats = vbr[16]
    root_entries = u16(vbr, 17)
    fatsz16 = u16(vbr, 22)
    fatsz32 = u32(vbr, 36)
    total = u32(vbr, 32)
    rootclus = u32(vbr, 44)
    if bps != 512 or spc not in (1, 2, 4, 8, 16, 32, 64, 128):
        raise ValueError("unsupported bytes/sector or invalid sectors/cluster")
    if not reserved or fats not in (1, 2) or not fatsz32 or fatsz16 or root_entries:
        raise ValueError("invalid FAT32 BPB layout")
    if total == 0 or total > candidates[0][3] or total <= reserved + fats*fatsz32:
        raise ValueError("invalid FAT32 total-sector geometry")
    clusters = (total - reserved - fats*fatsz32) // spc
    if clusters < 65525:
        raise ValueError("BPB describes too few clusters for FAT32")
    if not 2 <= rootclus < clusters+2:
        raise ValueError("root cluster outside FAT32 data area")
    fat = 64 + reserved
    data = fat + fats*fatsz32
    root_lba = data + (rootclus-2)*spc
    print(f"BPB: BPS={bps} SPC={spc} RESERVED={reserved} FATS={fats} FATSZ={fatsz32} ROOTCLUS={rootclus}")
    print(f"GEOMETRY: FAT={fat} DATA={data} ROOT={root_lba} CLUS={clusters}")
    if require_sd03 and (fat, data, root_lba, clusters) != (2112, 17472, 17472, 983007):
        raise ValueError("geometry differs from SD-03 physical UART evidence")
    print("SD05_FAT32_GEOMETRY_PASS")
    return fat, data, root_lba, clusters

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mbr",type=Path,default=Path("sd05_mbr.bin"))
    p.add_argument("--vbr",type=Path,default=Path("sd05_vbr.bin"))
    p.add_argument("--root",type=Path,default=Path("sd05_root.bin"))
    p.add_argument("--allow-other-card",action="store_true",help="skip hashes and SD-03 expected geometry")
    args=p.parse_args()
    try:
        check(args.mbr.read_bytes(),args.vbr.read_bytes(),args.root.read_bytes(),
              require_hashes=not args.allow_other_card,
              require_sd03=not args.allow_other_card)
    except (OSError,ValueError) as exc:
        p.exit(1,f"SD05_FAT32_GEOMETRY_FAIL: {exc}\n")

if __name__=="__main__":
    main()
