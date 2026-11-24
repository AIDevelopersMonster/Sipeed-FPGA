#!/usr/bin/env python3
"""Offline image attestations: tie a freestanding RV32 image to its UART build base."""
import argparse
import hashlib
import json
from pathlib import Path


def make_manifest(image: Path, uart_base: int) -> dict:
    if uart_base % 4 or not (0x80000000 <= uart_base <= 0xFFFF0000):
        raise ValueError('UART base must be aligned and in CPU IO region')
    raw=image.read_bytes()
    if not raw or len(raw) >= 0xC000:
        raise ValueError('image absent or too large')
    return dict(schema='pikosol20k-rv32-image-v1',target='EX20-05.16',
                cpu='vexriscv-min-rv32i_zicsr',
                image_sha256=hashlib.sha256(raw).hexdigest(),
                image_bytes=len(raw),uart_base=uart_base,
                video_base=0xB1000000,video_id=0x56323031,
                entry=0x40010000,stack_end=0x40020000,
                purpose='SDRAM-only experimental command shell; NOT board tested')


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image',type=Path)
    ap.add_argument('uart_base',type=lambda s:int(s,0))
    ap.add_argument('out',type=Path)
    args=ap.parse_args()
    obj=make_manifest(args.image,args.uart_base)
    args.out.write_text(json.dumps(obj,indent=2)+'\n',encoding='utf-8')
    print('BUILD MANIFEST:',args.out,'UART_BASE=0x%08X'%args.uart_base)


if __name__=='__main__':main()
