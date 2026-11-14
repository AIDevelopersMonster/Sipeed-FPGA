#!/usr/bin/env python3
"""Generate ONLY RAM mem_write lines for LiteX BIOS, never a boot command.
This is an offline formatter, not a loader or a readback verifier.
"""
from pathlib import Path
import sys
import hashlib
ENTRY = 0x40010000
MAX_CODE_END = 0x4001C000
if len(sys.argv) != 3:
    raise SystemExit("usage: image_to_memwrites.py image.bin output.txt")
image = Path(sys.argv[1]).read_bytes()
if not image or ENTRY + len(image) > MAX_CODE_END:
    raise SystemExit("Image empty or outside reserved SDRAM code/data region")
if (len(image) & 3) != 0:
    image += b"\x00" * (4 - (len(image) & 3))
lines = [f"# {len(image)} bytes padded, SHA256={hashlib.sha256(image).hexdigest()}",
         "# Offline list only. Verify generated csr.csv, board image, SDRAM and readback FIRST."]
for offset in range(0, len(image), 4):
    value = int.from_bytes(image[offset:offset+4], 'little')
    lines.append(f"mem_write 0x{ENTRY+offset:08X} 0x{value:08X}")
Path(sys.argv[2]).write_text("\n".join(lines)+"\n", encoding="ascii")
print(f"Generated {len(lines)-2} SDRAM write commands (NO boot, NO Flash)")
