#!/usr/bin/env python3
"""Decode an SD-04 512-byte sector UART HEX capture, read-only. Python 3.9+."""
import argparse
import pathlib
import sys

def decode_frame(raw):
    lines = [s.strip() for s in raw.splitlines() if s.strip()]
    if len(lines) != 1:
        raise ValueError("expected exactly one UART frame")
    frame = lines[0]
    if frame == b"ERROR":
        raise ValueError("FPGA reported SD/volume error")
    if len(frame) != 1024 or any(c not in b"0123456789ABCDEF" for c in frame):
        raise ValueError("expected 1024 uppercase hex characters")
    return bytes.fromhex(frame.decode("ascii"))

def decode_entries(sector):
    if len(sector) != 512:
        raise ValueError("sector must be exactly 512 bytes")
    for idx in range(16):
        entry = sector[idx*32:(idx+1)*32]
        if entry[0] == 0:
            break
        if entry[0] == 0xE5 or entry[11] == 0x0F or entry[11] & 0x08:
            continue
        if entry[11] & 0xC0:
            continue
        stem = entry[:8].decode("cp437").rstrip()
        ext = entry[8:11].decode("cp437").rstrip()
        if entry[0] == 0x05:
            stem = chr(0xE5) + stem[1:]
        name = stem + ("." + ext if ext else "")
        cluster = int.from_bytes(entry[20:22], "little") << 16
        cluster |= int.from_bytes(entry[26:28], "little")
        size = int.from_bytes(entry[28:32], "little")
        yield idx, name, entry[11], cluster, size

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("frame", type=pathlib.Path, help="UART capture file: 1024 hex chars + CRLF")
    ap.add_argument("--sector-out", type=pathlib.Path, help="optional raw 512-byte sector output")
    args = ap.parse_args()
    try:
        sector = decode_frame(args.frame.read_bytes())
        if args.sector_out:
            args.sector_out.write_bytes(sector)
        print("SD04 ROOT: 512 bytes; displaying 8.3 entries from first sector only")
        for index, name, attr, cluster, size in decode_entries(sector):
            print(f"{index:02d} {name:12s} ATTR={attr:02X} CLUS={cluster:08X} SIZE={size}")
        return 0
    except (OSError, ValueError) as e:
        print(f"SD04 ERROR: {e}", file=sys.stderr)
        return 1

if __name__ == "__main__":
    sys.exit(main())
