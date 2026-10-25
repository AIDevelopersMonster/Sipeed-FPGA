#!/usr/bin/env python3
"""Read-only FAT32 file cluster-chain inspection on accepted SD-05 FPGA."""
import argparse
import sys
from fat32_host import FAT32Volume, FAT32Error, SectorPort
from protocol import ProtocolError

def audit(volume, path):
    entry=volume.resolve(path)
    if entry is None or entry.is_dir:
        raise FAT32Error("expected a regular file")
    cluster_bytes=volume.spc*512
    expected=(entry.size+cluster_bytes-1)//cluster_bytes
    if expected==0:
        if entry.cluster != 0:
            raise FAT32Error("zero-size file has unexpected cluster")
        return [],0
    if expected > volume.max_sectors:
        raise FAT32Error("file requires more clusters than configured safety budget")
    sequence=[]
    seen=set()
    cluster=entry.cluster
    for _ in range(expected):
        volume._valid_cluster(cluster)
        if cluster in seen:
            raise FAT32Error("FAT cluster loop detected")
        seen.add(cluster)
        sequence.append(cluster)
        successor=volume.fat_next(cluster)
        if len(sequence)<expected:
            if successor is None:
                raise FAT32Error("FAT chain ended before file size")
            cluster=successor
        elif successor is not None:
            raise FAT32Error("FAT chain longer than file size")
    discontinuities=sum(b!=a+1 for a,b in zip(sequence,sequence[1:]))
    return sequence, discontinuities

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--port",required=True)
    p.add_argument("--path",required=True)
    p.add_argument("--max-sectors",type=int,default=512)
    a=p.parse_args()
    try:
        with SectorPort(a.port) as port:
            fs=FAT32Volume(port.read_sector,max_sectors=a.max_sectors)
            entry=fs.resolve(a.path)
            seq,gaps=audit(fs,a.path)
            print(f"SD052_CHAIN: FILE={a.path!r} SIZE={entry.size} SPC={fs.spc} "
                  f"CLUSTERS={len(seq)} DISCONTINUITIES={gaps}")
            print("SD052_CLUSTER_SEQUENCE: "+",".join(str(n) for n in seq))
            print("SD052_CHAIN_PASS")
    except (OSError,TimeoutError,ImportError,FAT32Error,ProtocolError) as e:
        print(f"SD052_CHAIN_FAIL: {e}",file=sys.stderr)
        return 1
    return 0

if __name__=="__main__":
    sys.exit(main())
