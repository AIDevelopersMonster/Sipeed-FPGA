#!/usr/bin/env python3
"""Convert real RISC-V GCC binary to exactly 4096 words of RV32I ROM."""
import argparse
import hashlib
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument("binary", type=Path)
    p.add_argument("hexfile", type=Path)
    a = p.parse_args()
    b = a.binary.read_bytes()
    if len(b) < 16 or len(b) > 16384 or len(b) % 4:
        raise SystemExit(f"LAB062_INVALID_BINARY_LENGTH: {len(b)}")
    words = [int.from_bytes(b[i:i+4], "little") for i in range(0,len(b),4)]
    words.extend([0x00000013]*(4096-len(words)))
    a.hexfile.write_text("".join(f"{x:08x}\n" for x in words),encoding="ascii")
    assert len(words)==4096
    print("LAB062_ROM_WORDS_PASS: 4096")
    print("LAB062_ROM_SHA256: "+hashlib.sha256(a.hexfile.read_bytes()).hexdigest().upper())

if __name__=="__main__":
    main()
