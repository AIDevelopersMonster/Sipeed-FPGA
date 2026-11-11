#!/usr/bin/env python3
"""Independent W01 Python oracle for identical RV32I ASM 32-bit semantics."""
MASK = 0xffffffff
EXPECTED = 0xB26F8CA7
def rol(x, n):
    return ((x << n) | (x >> (32-n))) & MASK

def work():
    ram = [0] * 32
    x = 0x12345678
    for i in range(32):
        x = ((x << 5) ^ (x >> 3) ^ i) & MASK
        ram[i] = x
    d = 0x9e3779b9
    for k in range(256):
        idx = k & 31
        v = ram[idx]
        x = (x ^ (x << 7)) & MASK
        x = (x ^ (x >> 9)) & MASK
        x = (x ^ (x << 8)) & MASK
        val = (((v+x+k) & MASK) ^ (v >> 3)) & MASK
        ram[idx] = val
        d = rol(d, 3) ^ val
        if val & 1:
            d = (d + 0xa5a5a5a5) & MASK
        else:
            d ^= 0x3c6ef372
    for v in ram:
        d = rol((d+v) & MASK,5)
    return d

if __name__ == "__main__":
    actual = work()
    print(f"W01_REFERENCE_DIGEST={actual:08X}")
    if actual != EXPECTED:
        raise SystemExit(f"W01_REFERENCE_FAIL expected={EXPECTED:08X}")
    print("W01_REFERENCE_PASS")
